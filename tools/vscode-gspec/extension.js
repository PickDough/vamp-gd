// Lists and runs gspec specs in the Test Explorer. All work goes through
// res://spec/support/vscode_runner.tscn, which prints one JSON event per line.
const vscode = require('vscode');
const cp = require('child_process');
const fs = require('fs');
const path = require('path');

const MARKER = '@@GSPEC@@';
const RUNNER_SCENE = 'res://spec/support/vscode_runner.tscn';

function activate(context) {
  const folder = (vscode.workspace.workspaceFolders || []).find((f) =>
    fs.existsSync(path.join(f.uri.fsPath, 'project.godot')),
  );
  if (!folder) {
    return;
  }
  const root = folder.uri.fsPath;

  const controller = vscode.tests.createTestController('gspec', 'GSpec');
  context.subscriptions.push(controller);

  // Test item -> { file, filter } for running it: the spec file plus a description filter.
  const targets = new WeakMap();

  const toUri = (resPath) => vscode.Uri.file(path.join(root, resPath.replace(/^res:\/\//, '')));

  // Runs the engine with the runner scene, calling onEvent per JSON event and onOutput per other line.
  function runEngine(args, token, onEvent, onOutput) {
    return new Promise((resolve) => {
      const redot = vscode.workspace.getConfiguration('gspec').get('redotPath');
      const engine = cp.spawn(redot, ['--headless', '--path', root, RUNNER_SCENE, '--', ...args], { cwd: root });
      if (token) {
        token.onCancellationRequested(() => engine.kill());
      }

      const readLines = (stream) => {
        let pending = '';
        stream.on('data', (chunk) => {
          const lines = (pending + chunk.toString()).split('\n');
          pending = lines.pop();
          for (const line of lines) {
            const at = line.indexOf(MARKER);
            if (at < 0) {
              onOutput(line);
              continue;
            }
            try {
              onEvent(JSON.parse(line.slice(at + MARKER.length)));
            } catch {
              onOutput(line);
            }
          }
        });
      };
      readLines(engine.stdout);
      readLines(engine.stderr);

      engine.on('error', (error) => {
        onOutput(`Could not start Redot at "${redot}" (setting gspec.redotPath): ${error.message}`);
        resolve();
      });
      engine.on('close', () => resolve());
    });
  }

  // Zero-based line of a description in the spec source. Formatted descriptions
  // ("builds a walkable %s ...") only match by a prefix of their words.
  function lineOf(lines, description) {
    const words = description.split(' ');
    for (let count = words.length; count >= 2; count--) {
      const prefix = '"' + words.slice(0, count).join(' ');
      const index = lines.findIndex((line) => line.includes(prefix));
      if (index >= 0) {
        return index;
      }
    }
    return 0;
  }

  function createItem(id, label, uri, lines, target) {
    const item = controller.createTestItem(id, label, uri);
    item.range = new vscode.Range(lineOf(lines, label), 0, lineOf(lines, label), 0);
    targets.set(item, target);
    return item;
  }

  // Discovery runs one at a time; a request during a run starts one more pass afterwards.
  let discovering = null;
  let discoverAgain = false;
  function discover() {
    if (discovering) {
      discoverAgain = true;
      return discovering;
    }
    discovering = discoverOnce().finally(() => {
      discovering = null;
      if (discoverAgain) {
        discoverAgain = false;
        discover();
      }
    });
    return discovering;
  }

  async function discoverOnce() {
    const found = [];
    const output = [];
    await runEngine(['--list'], undefined, (event) => {
      if (event.event === 'test') {
        found.push(event);
      }
    }, (line) => output.push(line));

    const files = new Map();
    for (const test of found) {
      const uri = toUri(test.file);
      const lines = fs.readFileSync(uri.fsPath, 'utf8').split('\n');

      let parent = files.get(test.file);
      if (!parent) {
        parent = controller.createTestItem(test.file, path.basename(uri.fsPath), uri);
        targets.set(parent, { file: test.file, filter: null });
        files.set(test.file, parent);
      }

      const groups = [];
      for (const group of test.groups) {
        groups.push(group);
        const id = `${test.file}::${groups.join(' > ')}`;
        let item = parent.children.get(id);
        if (!item) {
          item = createItem(id, group, uri, lines, { file: test.file, filter: groups.join(' > ') });
          parent.children.add(item);
        }
        parent = item;
      }

      const fullDescription = groups.length ? `${groups.join(' > ')} ${test.name}` : test.name;
      const item = createItem(test.id, test.name, uri, lines, { file: test.file, filter: fullDescription });
      parent.children.add(item);
    }
    controller.items.replace([...files.values()]);

    if (found.length === 0 && output.some((line) => line.includes('ERROR'))) {
      vscode.window.showWarningMessage('GSpec found no specs; see the engine output in the GSpec test run log.');
    }
  }

  function leavesOf(item) {
    if (item.children.size === 0) {
      return [item];
    }
    const leaves = [];
    item.children.forEach((child) => leaves.push(...leavesOf(child)));
    return leaves;
  }

  async function runTests(request, token) {
    const run = controller.createTestRun(request);
    const excluded = new Set(request.exclude || []);
    const requested = [];
    (request.include || controller.items).forEach((item) => requested.push(item));

    // One engine run per requested item: its spec file, filtered down to that item.
    for (const item of requested) {
      if (token.isCancellationRequested) {
        break;
      }
      const target = targets.get(item);
      if (!target) {
        continue;
      }

      const leaves = leavesOf(item).filter((leaf) => !excluded.has(leaf));
      const leavesById = new Map(leaves.map((leaf) => [leaf.id, leaf]));
      leaves.forEach((leaf) => run.started(leaf));

      const reported = new Set();
      const output = [];
      const args = target.filter ? ['--filter', target.filter, target.file] : [target.file];
      await runEngine(args, token, (event) => {
        if (event.event !== 'result') {
          return;
        }
        const test = leavesById.get(event.id);
        if (!test) {
          return;
        }
        reported.add(test);

        if (event.status === 'passed') {
          run.passed(test, event.duration_ms);
        } else if (event.status === 'pending') {
          run.skipped(test);
        } else {
          const messages = (event.failures.length ? event.failures : [event.status]).map((text) => {
            const message = new vscode.TestMessage(text);
            message.location = new vscode.Location(test.uri, test.range);
            return message;
          });
          run.failed(test, messages, event.duration_ms);
        }
      }, (line) => {
        output.push(line);
        run.appendOutput(line + '\r\n');
      });

      for (const leaf of leaves) {
        if (!reported.has(leaf) && !token.isCancellationRequested) {
          run.errored(leaf, new vscode.TestMessage('The spec run reported no result. Last engine output:\n' + output.slice(-20).join('\n')));
        }
      }
    }
    run.end();
  }

  controller.refreshHandler = discover;
  controller.createRunProfile('Run', vscode.TestRunProfileKind.Run, runTests, true);

  let pendingDiscovery;
  const rediscover = () => {
    clearTimeout(pendingDiscovery);
    pendingDiscovery = setTimeout(discover, 500);
  };
  const watcher = vscode.workspace.createFileSystemWatcher(new vscode.RelativePattern(folder, 'spec/**/*.gd'));
  watcher.onDidChange(rediscover);
  watcher.onDidCreate(rediscover);
  watcher.onDidDelete(rediscover);
  context.subscriptions.push(watcher);

  discover();
}

function deactivate() {}

module.exports = { activate, deactivate };
