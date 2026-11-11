#!/usr/bin/env python3
"""Capture the native gallery on an already-running emulator; restores display/font settings."""
import argparse
import pathlib
import re
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--adb', default='adb')
parser.add_argument('--serial', required=True)
parser.add_argument('--output', default='.impeccable/review/android')
args = parser.parse_args()
out = pathlib.Path(args.output)
out.mkdir(parents=True, exist_ok=True)

def adb(*items):
    return subprocess.check_output([args.adb, '-s', args.serial, *items])

def shell(*items):
    return adb('shell', *items).decode().strip()

def capture(name, theme, filename, wait=1.4):
    shell('am', 'force-stop', 'dev.aielements.gallery')
    command = ['am', 'start', '-W', '-n', 'dev.aielements.gallery/.MainActivity', '-f', '0x10008000', '--es', 'theme', theme]
    if name:
        # adb shell reassembles arguments, so quote spaces in extra values.
        command += ['--es', 'pattern', "'" + name + "'"]
    shell(*command)
    time.sleep(wait)
    try:
        shell('pidof', 'dev.aielements.gallery')
    except subprocess.CalledProcessError as error:
        raise RuntimeError(f'Gallery exited before capture: {filename}; inspect adb logcat -b crash') from error
    focus = next((line for line in shell('dumpsys', 'window').splitlines() if 'mCurrentFocus=' in line), '')
    if 'dev.aielements.gallery/' not in focus:
        raise RuntimeError(f'Capture obstructed: {filename}: {focus}')
    (out / filename).write_bytes(adb('exec-out', 'screencap', '-p'))
    print(filename, flush=True)

original_font = shell('settings', 'get', 'system', 'font_scale')
original_size = re.search(r'Override size: (\S+)', shell('wm', 'size'))
original_density = re.search(r'Override density: (\S+)', shell('wm', 'density'))
try:
    shell('wm', 'size', '1080x2400')
    shell('wm', 'density', '480')  # 360 dp narrow phone
    shell('settings', 'put', 'system', 'font_scale', '1.0')
    names = ['Chain of Thought', 'Chat', 'Checkpoint', 'Confirmation', 'Context', 'File Tree', 'Inline Citation', 'Message', 'Model Selector', 'Plan', 'Prompt Input', 'Queue', 'Reasoning', 'Sources', 'Stack Trace', 'Subagent', 'Suggestion', 'Task', 'Terminal', 'Test Results', 'Tool', 'Generative UI', 'stack', 'row', 'card', 'text', 'button', 'badge', 'input', 'select', 'switch', 'progress', 'separator', 'table', 'bar-chart', 'line-chart', 'area-chart']
    for theme in ['Light', 'Dark']:
        capture(None, theme, f'phone-catalog-{theme.lower()}.png')
        for name in names:
            capture(name, theme, f'phone-{name.lower().replace(" ", "-")}-{theme.lower()}.png', wait=4.2 if name == 'Generative UI' else 1.4)
    shell('settings', 'put', 'system', 'font_scale', '1.3')
    for name in ['Chat', 'Confirmation', 'Inline Citation', 'Prompt Input', 'table', 'card', 'Generative UI']:
        capture(name, 'Dark', f'phone-large-text-{name.lower().replace(" ", "-")}.png', wait=4.2 if name == 'Generative UI' else 1.4)
    shell('settings', 'put', 'system', 'font_scale', '1.0')
    shell('wm', 'size', '2400x1080')
    for theme in ['Light', 'Dark']:
        for name in ['Chat', 'Prompt Input', 'table']:
            capture(name, theme, f'phone-landscape-{name.lower().replace(" ", "-")}-{theme.lower()}.png')
    shell('wm', 'size', '1600x2560')
    shell('wm', 'density', '240')
    for theme in ['Light', 'Dark']:
        for name in ['Generative UI', 'area-chart']:
            capture(name, theme, f'tablet-portrait-{name.lower().replace(" ", "-")}-{theme.lower()}.png', wait=4.2)
    shell('wm', 'size', '2560x1600')
    shell('wm', 'density', '240')
    for theme in ['Light', 'Dark']:
        capture('Generative UI', theme, f'tablet-{theme.lower()}.png', wait=4.2)
finally:
    shell('wm', 'size', original_size.group(1) if original_size else 'reset')
    shell('wm', 'density', original_density.group(1) if original_density else 'reset')
    if original_font == 'null':
        shell('settings', 'delete', 'system', 'font_scale')
    else:
        shell('settings', 'put', 'system', 'font_scale', original_font)
