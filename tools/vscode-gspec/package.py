"""Packs this folder into vscode-gspec.vsix without needing Node or vsce.

Install with: code --install-extension tools/vscode-gspec/vscode-gspec.vsix
"""
import json
import pathlib
import zipfile

HERE = pathlib.Path(__file__).parent
FILES = ["package.json", "extension.js"]

package = json.loads((HERE / "package.json").read_text())

manifest = f"""<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Language="en-US" Id="{package["name"]}" Version="{package["version"]}" Publisher="{package["publisher"]}" />
    <DisplayName>{package["displayName"]}</DisplayName>
    <Description xml:space="preserve">{package["description"]}</Description>
    <Categories>Testing</Categories>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="{package["engines"]["vscode"]}" />
    </Properties>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code" />
  </Installation>
  <Dependencies />
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" />
  </Assets>
</PackageManifest>
"""

content_types = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json" />
  <Default Extension=".js" ContentType="application/javascript" />
  <Default Extension=".vsixmanifest" ContentType="text/xml" />
</Types>
"""

target = HERE / f"{package['name']}.vsix"
with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as vsix:
    vsix.writestr("extension.vsixmanifest", manifest)
    vsix.writestr("[Content_Types].xml", content_types)
    for name in FILES:
        vsix.write(HERE / name, f"extension/{name}")

print(target)
