using System;
using System.Collections.Generic;
using System.Linq;
using GdSharpExtensions.TreeQuery;
using Godot;
using vampgd.scenes.globals;

namespace vampgd.enemies.spawning;

public partial class EnemySpawner : Node3D
{
    [Export]
    public List<SpawnScenario> SpawnScenarios = [];

    [Export]
    public float TickIntervalSeconds = 1f;

    [Export]
    public int SubTicksPerTick = 3;

    private int currentSubTick = 0;
    private double timeSinceStart = 0f;
    private NavigationRegion3D navigationRegion = null!;
    private AutoloadGame game = null!;

    public override void _EnterTree()
    {
        navigationRegion = GetParent().FindUnder<NavigationRegion3D>()!;
        game = this.FindAutoload<AutoloadGame>("AutoloadGame")!;
    }

    // Called when the node enters the scene tree for the first time.
    public override void _Ready()
    {
        var timer = new Timer();
        timer.WaitTime = TickIntervalSeconds / SubTicksPerTick;
        timer.OneShot = false;
        timer.Timeout += OnTick;

        SpawnScenarios.Sort((a, b) => a.StartTime.CompareTo(b.StartTime));

        AddChild(timer);
    }

    private void OnTick()
    {
        var currentScenario = SpawnScenarios.First(s => s.StartTime <= timeSinceStart);
        var spawnAmount = currentScenario.AmountPerTick / SubTicksPerTick;

        for (var i = 0; i < SubTicksPerTick; i++)
        {
            SpawnEnemy(currentScenario, spawnAmount);
        }
    }

    private void SpawnEnemy(SpawnScenario currentScenario, float spawnAmount) { }

    // Called every frame. 'delta' is the elapsed time since the previous frame.

    public override void _Process(double delta) { }
}

