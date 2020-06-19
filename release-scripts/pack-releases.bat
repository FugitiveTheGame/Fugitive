@echo off

echo --=== Packing Windows ===--
powershell Remove-Item releases/Fugitive_Windows.zip
powershell Copy-Item -Path READ_ME.txt -Destination ../export/windows/
powershell Compress-Archive -Path ../export/windows/* -CompressionLevel Optimal -DestinationPath releases/Fugitive_Windows.zip


echo --=== Packing Linux ===--
powershell Remove-Item releases/Fugitive_Linux.zip
powershell Copy-Item -Path READ_ME.txt -Destination ../export/linux/
powershell Compress-Archive -Path ../export/linux/* -CompressionLevel Optimal -DestinationPath releases/Fugitive_Linux.zip


echo --=== Packing OSX ===--
powershell Remove-Item releases/Fugitive_OSX.zip
powershell Copy-Item -Path READ_ME.txt -Destination ../export/osx/
powershell Compress-Archive -Path ../export/osx/* -CompressionLevel Optimal -DestinationPath releases/Fugitive_OSX.zip
