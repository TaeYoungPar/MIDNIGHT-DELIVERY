"""Check the actual Rojo artifact, including every source and both bootstraps."""
from pathlib import Path
import xml.etree.ElementTree as ET

root = ET.parse('build/MidnightDelivery.rbxlx').getroot()
scripts = [i for i in root.iter('Item') if i.attrib['class'] in ('Script', 'LocalScript', 'ModuleScript')]
sources = [i.find("Properties/*[@name='Source']").text for i in scripts]
expected = list(Path('src').rglob('*.luau'))
assert len(scripts) == len(expected), (len(scripts), len(expected))
for path in expected:
    assert path.read_text() in sources, f'Missing or changed source: {path}'
for service, branch, kind in [('ServerScriptService', 'Server', 'Script'), ('StarterPlayer', 'StarterPlayerScripts', 'LocalScript')]:
    service_node = next(i for i in root.findall('Item') if i.attrib['class'] == service)
    assert any(i.attrib['class'] == kind for i in service_node.iter('Item')), (service, branch, kind)
assert not any(i.attrib['class'] in ('Script', 'LocalScript') for i in root.findall("Item[@class='ReplicatedStorage']/Item"))
print(f'PASS Rojo artifact contains all {len(expected)} sources, server Script and client LocalScript')
