$client = New-Object System.Net.Sockets.TcpClient('127.0.0.1', 9999)
$stream = $client.GetStream()
$writer = New-Object System.IO.StreamWriter($stream)
$reader = New-Object System.IO.StreamReader($stream)

# Click the Dungeon button
$writer.WriteLine('{"action":"click_button","path":"/root/Main/WorldView/HBoxContainer/DungeonButton"}')
$writer.Flush()

Start-Sleep -Milliseconds 1000

$response = $reader.ReadLine()
Write-Output "Click response: $response"

$client.Close()
