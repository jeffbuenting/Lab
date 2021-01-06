# ----- https://artisticcheese.wordpress.com/2017/06/10/using-pure-powershell-to-generate-tls-certificates-for-docker-daemon-running-on-windows/

$Path = 'C:\certs'
$SwarmManager = "WDockMngr01"
$DockerHost = @(@{Name = "KW-WCont01";IP = "192.168.1.60"})

$rootCert = Get-ChildItem cert:\currentuser\my | where subject -eq 'CN=Docker TLS Root'

if ( -Not ( $rootCert ) ) {
    Write-Output "Creating Root Cert"

    # ----- Create CA Cert
    $splat = @{
        type = "Custom" ;
        KeyExportPolicy = "Exportable";
        Subject = "CN=Docker TLS Root";
        CertStoreLocation = "Cert:\CurrentUser\My";
        HashAlgorithm = "sha256";
        KeyLength = 4096;
        KeyUsage = @("CertSign", "CRLSign");
        TextExtension = @("2.5.29.19 ={critical} {text}ca=1")
    }
    $rootCert = New-SelfSignedCertificate @splat

    # ----- Export public key root cer
    $splat = @{
        Path = "$Path\rootCA.cer";
        Value = "-----BEGIN CERTIFICATE-----`n" + [System.Convert]::ToBase64String($rootCert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks) + "`n-----END CERTIFICATE-----";
        Encoding = "ASCII";
    }
    Set-Content @splat
}

foreach ( $D in $DockerHost ) {
    Write-Output "Checking if Cert $D exists"

    if ( -Not ( Get-ChildItem cert:\currentuser\my | where DnsNameList -contains $D ) ) {
        Write-output "Creating $($D.Name)"

        # ----- Server Cert
        $splat = @{
            FriendlyName = "$($D.Name)"
            Subject = "$($D.Name)"
            CertStoreLocation = "Cert:\CurrentUser\My";
            Signer = $rootCert ;
            KeyExportPolicy = "Exportable";
            Provider = "Microsoft Enhanced Cryptographic Provider v1.0";
            Type = "SSLServerAuthentication";
            HashAlgorithm = "sha256";
            TextExtension = @("2.5.29.37= {text}1.3.6.1.5.5.7.3.1","2.5.29.17={text}IPAddress=$($D.IP)&DNS=localhost");
            KeyLength = 4096;
        }
        $serverCert = New-SelfSignedCertificate @splat

        $splat = @{
            Path = "$Path\$($D.Name)-SVRCert.cer";
            Value = "-----BEGIN CERTIFICATE-----`n" + [System.Convert]::ToBase64String($serverCert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks) + "`n-----END CERTIFICATE-----";
            Encoding = "Ascii"
        }
        Set-Content @splat

        # ----- Export Server Cert
        $privateKeyFromCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($serverCert)

        $splat = @{
            Path = "$Path\$($D.Name)-privateKey.cer";
            Value = ("-----BEGIN RSA PRIVATE KEY-----`n" + [System.Convert]::ToBase64String($privateKeyFromCert.Key.Export([System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob), [System.Base64FormattingOptions]::InsertLineBreaks) + "`n-----END RSA PRIVATE KEY-----");
            Encoding = "Ascii";
        }
        Set-Content @splat
    }
}


if ( -Not ( Get-ChildItem cert:\currentuser\my | where subject -eq 'CN=clientCert' ) ) {
    Write-Output "Creating client cert"

    # ----- Client Certs
    $splat = @{
        CertStoreLocation = "Cert:\CurrentUser\My";
        Subject = "CN=clientCert";
        Signer = $rootCert ;
        KeyExportPolicy = "Exportable";
        Provider = "Microsoft Enhanced Cryptographic Provider v1.0";
        TextExtension = @("2.5.29.37= {text}1.3.6.1.5.5.7.3.2") ;
        HashAlgorithm = "sha256";
        KeyLength = 4096;
    }
    $clientCert = New-SelfSignedCertificate  @splat

    $splat = @{
        Path = "$Path\clientPublicKey.cer" ;
        Value = ("-----BEGIN CERTIFICATE-----`n" + [System.Convert]::ToBase64String($clientCert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks) + "`n-----END CERTIFICATE-----");
        Encoding = "Ascii";
    }
    Set-Content  @splat

    $clientprivateKeyFromCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($clientCert)

    $splat = @{
        Path = "$Path\clientPrivateKey.cer";
        Value = ("-----BEGIN RSA PRIVATE KEY-----`n" + [System.Convert]::ToBase64String($clientprivateKeyFromCert.Key.Export([System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob), [System.Base64FormattingOptions]::InsertLineBreaks) + "`n-----END RSA PRIVATE KEY-----");
        Encoding = "Ascii";
    }
    Set-Content  @splat
}