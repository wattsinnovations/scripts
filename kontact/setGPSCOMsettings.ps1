
###################################################
## script to set com settings in kontact for remote id
## chris baquol watts innovations 3/3/23
###################################################

Add-Type -AssemblyName PresentationFramework

Try {
    $port = new-Object System.IO.Ports.SerialPort('COM30', 9600, 'None', 8, 'One')
    $port.Open()

    #sets rate to 200ms
    $byte_string = [byte[]]@(0xB5, 0x62, 0x06, 0x08, 0x06, 0x00, 0xC8, 0x00, 0x01, 0x00, 0x01, 0x00, 0xDE, 0x6A)
    $port.Write($byte_string, 0, $byte_string.Length)
    sleep(1)
    #sets baud to 115200
    $byte_string = [byte[]]@(0xb5, 0x62, 0x06, 0x00, 0x14, 0x00, 0x01, 0x00, 0x00, 0x00, 0xd0, 0x08, 0x00, 0x00, 0x00, 0xc2, 0x01, 0x00, 0x07, 0x00, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc4, 0x96, 0xb5, 0x62, 0x06, 0x00, 0x01, 0x00, 0x01, 0x08, 0x22)
    $port.Write($byte_string, 0, $byte_string.Length)
   


    $port.Close()
}

Catch {

    $msgBoxInput =  [System.Windows.MessageBox]::Show('Please install batteries into the rear of KONTACT, then press OK to reboot.', 'WARNING: Batteries Not Detected', 'OKCancel','Error')

    switch  ($msgBoxInput) {
    
       'OK' {
           	sleep(1)
            Restart-Computer -Force
       }
    
      'Cancel' {
    	## Do nothing
      }

    }

}