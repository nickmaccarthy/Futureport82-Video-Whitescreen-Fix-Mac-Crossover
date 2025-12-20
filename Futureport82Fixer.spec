# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['find-bottles-gui.py'],
    pathex=[],
    binaries=[],
    datas=[('system32', 'system32'), ('syswow64', 'syswow64'), ('mf-fix-cx.sh', '.'), ('mf.reg', '.'), ('wmf.reg', '.'), ('mfplat.dll', '.'), ('VERSION.md', '.')],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='Futureport82Fixer',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch='arm64',
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='Futureport82Fixer',
)
app = BUNDLE(
    coll,
    name='Futureport82Fixer.app',
    icon=None,
    bundle_identifier='com.futureport82.fixer',
)
