#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';

const [mode, ...args] = process.argv.slice(2);
const expected = [
  '01-Wealth', '05-GIV-Markets', '06-GIV-Performance', '07-GIV-Analysis',
  '02-Select-accounts', '03-Add-a-portfolio', '04-Review-holdings', '08-Compare-accounts',
];
const allowedPortraitSizes = {
  iphone: ['1260x2736', '1290x2796', '1320x2868'],
  ipad: ['2064x2752', '2048x2732'],
};

if (mode === 'devices') {
  const devices = JSON.parse(execFileSync('xcrun', ['simctl', 'list', 'devices', 'available', '-j'], { encoding: 'utf8' }));
  const names = { iphone: 'iPhone 17 Pro Max', ipad: 'iPad Pro 13-inch (M5)' };
  for (const group of args[0] === 'all' ? ['iphone', 'ipad'] : [args[0]]) {
    const matches = Object.entries(devices.devices).flatMap(([runtime, list]) =>
      list.filter(device => device.name === names[group]).map(device => ({ ...device, runtime })));
    matches.sort((a, b) => b.runtime.localeCompare(a.runtime, undefined, { numeric: true }));
    if (!matches[0]) throw new Error(`No available ${names[group]} simulator. Install it in Xcode first.`);
    const device = matches[0];
    console.log([group, device.udid, device.name, device.runtime].join('\t'));
  }
} else if (mode === 'export') {
  const [deviceDir, group, device, runtime, infoPath] = args;
  const entries = JSON.parse(await fs.readFile(path.join(deviceDir, 'attachments/manifest.json'), 'utf8'));
  const attachments = entries.flatMap(entry => entry.attachments || []);
  const info = JSON.parse(execFileSync('plutil', ['-convert', 'json', '-o', '-', infoPath], { encoding: 'utf8' }));
  const outputDir = path.join(deviceDir, 'PNG');
  await fs.mkdir(outputDir, { recursive: true });
  const screenshots = [];
  for (const [index, name] of expected.entries()) {
    const matches = attachments.filter(item => item.suggestedHumanReadableName?.includes(`APPSTORE-${name}`));
    if (matches.length !== 1) throw new Error(`Expected one ${name} screenshot, found ${matches.length}.`);
    const item = matches[0];
    const buffer = await fs.readFile(path.join(deviceDir, 'attachments', item.exportedFileName));
    if (!buffer.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) {
      throw new Error(`${name} is not an original PNG attachment.`);
    }
    const width = buffer.readUInt32BE(16), height = buffer.readUInt32BE(20), colorType = buffer[25];
    let hasAlpha = [4, 6].includes(colorType);
    for (let offset = 8; offset + 12 <= buffer.length;) {
      const length = buffer.readUInt32BE(offset), type = buffer.toString('ascii', offset + 4, offset + 8);
      if (type === 'tRNS') hasAlpha = true;
      offset += 12 + length;
      if (type === 'IEND') break;
    }
    const sizeAccepted = allowedPortraitSizes[group].includes(`${width}x${height}`);
    const orderedName = `${String(index + 1).padStart(2, '0')}-${name.slice(3)}`;
    const filename = `${orderedName}.png`;
    await fs.writeFile(path.join(outputDir, filename), buffer);
    screenshots.push({ name: orderedName, sourceAttachmentName: name, file: `PNG/${filename}`, width, height, hasAlpha, sizeAccepted,
      bytes: buffer.length, sha256: crypto.createHash('sha256').update(buffer).digest('hex') });
  }
  const manifest = { device, runtime, group, version: info.CFBundleShortVersionString,
    build: info.CFBundleVersion, source: 'XCUIScreen.main.screenshot() XCTest attachments',
    transformed: false, screenshots };
  await fs.writeFile(path.join(deviceDir, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  console.log(`${group}: ${screenshots.length} original PNGs; ${screenshots[0].width}x${screenshots[0].height}; alpha=${screenshots.some(item => item.hasAlpha)}`);
  if (screenshots.some(item => !item.sizeAccepted)) throw new Error('Unexpected native screenshot dimensions; inspect manifest.json.');
  if (screenshots.some(item => item.hasAlpha)) console.log('Alpha channel detected. Originals retained unchanged; request approval before any conversion.');
} else if (mode === 'index') {
  const [runDir] = args;
  const manifests = [];
  for (const group of ['iphone', 'ipad']) {
    try { manifests.push(JSON.parse(await fs.readFile(path.join(runDir, group, 'manifest.json'), 'utf8'))); }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
  const lines = ['# Native App Store / review screenshots', '',
    'Original PNG attachments captured from the running native app. No resizing, compositing, or pixel edits.', '',
    '| Device | Version | Page | Native pixels | Alpha | PNG |', '| --- | --- | --- | --- | --- | --- |'];
  for (const manifest of manifests) for (const item of manifest.screenshots) {
    lines.push(`| ${manifest.device} | ${manifest.version} (${manifest.build}) | ${item.name} | ${item.width} × ${item.height} | ${item.hasAlpha ? 'Yes — requires conversion before App Store upload' : 'No'} | [Open](${manifest.group}/${item.file}) |`);
  }
  lines.push('', 'Each device directory contains the XCTest result bundle, logs, original exported attachments, and a manifest with SHA-256 hashes.', '');
  await fs.writeFile(path.join(runDir, 'README.md'), lines.join('\n'));
  await fs.writeFile(path.join(runDir, 'manifest.json'), JSON.stringify(manifests, null, 2) + '\n');
} else {
  throw new Error('Expected devices, export, or index mode.');
}
