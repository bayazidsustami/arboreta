----------------------------------code-----------------------------------import Data.Time.Clock, Control.Concurrent, Text.Printf, Data.List, System.Environment, Data.ByteString.Char8 as BString, Data.Functor.Yield( yield ), System.Random------------------------------------byteStringToWord8------------------------------------_/------------------------------------_/\------------------------------------T/\-------------------------------------/\/\/\------------------------------------`/\/\/\/\------------------------------------`\
session--------------------------------------------detail-------------------------------------init-top
(initTlsWithVenya,"Handshake success")
Initializing TLS session...
Found 20 cipher suites. Negotiating TLS 1.3.
Send ServerHello: \x16\x03\x01
--------------------------ServerHelloReceived
Parsed TLS 1.3 ServerHello
--------------------------EncryptedExtensions
Received cipher suite (0x0013)
Received signature algorithm (0x04)
Received supported groups (prime256v1)
--------------------------ClientKeyExchange
Sent key exchange
--------------------------Finished
Session established. Starting secrets exchange...
--------------------------Alert
Received fatal TLS alert: protocol_version (0x80)
Unexpected protocol: TLS 1.3
Terminating TLS session...
--------------------------close
Session closed.
-----------------------------------message----------------------------------end-message----------------------------------message______________________________ session __________________________ detail __________________________ init-top__________________________________ begun______________'\