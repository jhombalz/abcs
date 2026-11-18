$ErrorActionPreference = 'Stop'
$audioPath = Join-Path $PSScriptRoot '../client/assets/audio'
New-Item -ItemType Directory -Path $audioPath -Force | Out-Null
$cues = @{
  round = @(523.25, 659.25)
  buzz = @(220, 330)
  point = @(659.25, 783.99, 1046.5)
  finish = @(523.25, 659.25, 783.99, 1046.5)
}
$rate = 22050
$frames = 2205
foreach ($cue in $cues.GetEnumerator()) {
  $stream = [IO.File]::Create((Join-Path $audioPath ($cue.Key + '.wav')))
  $writer = New-Object IO.BinaryWriter($stream)
  try {
    $dataSize = $frames * $cue.Value.Count * 2
    $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
    $writer.Write([int](36 + $dataSize))
    $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
    $writer.Write([int]16)
    $writer.Write([int16]1)
    $writer.Write([int16]1)
    $writer.Write([int]$rate)
    $writer.Write([int]($rate * 2))
    $writer.Write([int16]2)
    $writer.Write([int16]16)
    $writer.Write([Text.Encoding]::ASCII.GetBytes('data'))
    $writer.Write([int]$dataSize)
    foreach ($frequency in $cue.Value) {
      for ($frame = 0; $frame -lt $frames; $frame++) {
        $envelope = [Math]::Sin([Math]::PI * $frame / $frames)
        $sample = [Math]::Sin(2 * [Math]::PI * $frequency * $frame / $rate)
        $writer.Write([int16]($sample * $envelope * 5500))
      }
    }
  } finally { $writer.Dispose() }
}
