param([string[]]$Tests = @())
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$studio = 'C:/Program Files/Android/Android Studio'
$java = Join-Path $studio 'jbr/bin/java.exe'
$compiler = Join-Path $studio 'plugins/Kotlin/kotlinc/lib'
$junit = Join-Path $root '../../.tools/junit-4.13.2.jar'
$hamcrest = Join-Path $root '../../.tools/hamcrest-core-1.3.jar'
$out = Join-Path $root 'build/geometry-tests'
New-Item -ItemType Directory -Force $out | Out-Null
$native = Join-Path $root 'android/app/src/main/kotlin/ir/bootic/store_app'
$testRoot = Join-Path $root 'android/app/src/test/kotlin/ir/bootic/store_app'
$names = @('GarmentWarp','PhotoSurface','PhotoCloth','BodyEdgeFit','PoseGeometry','TryonEffectGeometry','CameraFrameCrop','GestureVoteGate','GarmentModel')
$sources = @($names | ForEach-Object { $p = Join-Path $native "$_.kt"; if (Test-Path $p) { $p } })
$testFiles = @(Get-ChildItem $testRoot -Filter '*Test.kt')
$classpath = "$compiler/kotlin-stdlib.jar;$junit;$hamcrest"
& $java -cp "$compiler/*" org.jetbrains.kotlin.cli.jvm.K2JVMCompiler -no-stdlib -no-reflect -jvm-target 17 -classpath $classpath -d "$out/tests.jar" @sources @($testFiles.FullName)
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($Tests.Count -eq 0) { $Tests = @($testFiles | ForEach-Object { 'ir.bootic.store_app.' + $_.BaseName }) }
& $java -cp "$out/tests.jar;$classpath" org.junit.runner.JUnitCore @Tests
exit $LASTEXITCODE
