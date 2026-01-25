"""
py2app build configuration for Dictation menu bar app.

Prerequisites:
    pip install py2app

Build commands:
    Development (alias build, fast):
        python setup.py py2app -A

    Production (standalone):
        python setup.py py2app

The built app will be in dist/Dictation.app
"""

from setuptools import setup

APP = ['dictation.py']

OPTIONS = {
    'argv_emulation': False,
    'plist': {
        'CFBundleName': 'Dictation',
        'CFBundleDisplayName': 'Dictation',
        'CFBundleIdentifier': 'com.local.dictation',
        'CFBundleVersion': '0.2.0',
        'CFBundleShortVersionString': '0.2.0',
        'LSUIElement': True,  # Menu bar only, no Dock icon
        'NSMicrophoneUsageDescription': 'Dictation needs microphone access for speech-to-text.',
        'NSAppleEventsUsageDescription': 'Dictation needs accessibility access for global hotkeys.',
    },
    'packages': [
        'whisper',
        'torch',
        'numpy',
        'sounddevice',
        'rumps',
        'pynput',
        'ollama',
    ],
    'includes': [
        'tiktoken',
        'tiktoken_ext',
        'tiktoken_ext.openai_public',
    ],
    'excludes': [
        'matplotlib',
        'tkinter',
        'PIL',
    ],
}

setup(
    name='Dictation',
    app=APP,
    options={'py2app': OPTIONS},
)
