Function Register-VirtualMachine {

PARAM
(
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $ActiveDirectoryComputerName 
	,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $MacAddress
	,
	[Parameter(Mandatory = $true, ParameterSetName = 'DHCP')]
	[ValidateNotNullOrEmpty()]
	[switch] $dhcp
	,
	[Parameter(Mandatory = $false)]
	[string] $CumulusWindowsFeatures = $null
	,
	[Parameter(Mandatory = $false)]
	[ValidateSet("100full","1000full")]
	[string] $NetworkSpeed = "1000full"
	,
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[string] $Trend = "True"
	,
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[string] $ApplicationTree = "False"
	,
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[string] $ApplicationProfile = "None"
	,
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[string] $BypassChooser = "True"
	,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $ComputerDomain
	,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	# [ValidateSet("2003STDx86","2003ENTx86","2003STDR2x86","2003ENTR2x86","2008STDx86","2008ENTx86","2003STDx64","2003ENTx64","2003STDR2x64","2003ENTR2x64","2008STDR2x64","2008ENTR2x64","2012STDx64","2012DCEx64")]
	[string] $OperatingSystem
	,
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[string] $TargetCollectionName = "OSD-Server_Deployment-Unattended"
	,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $EmailAddress
	,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $SCCMSiteCode
	,
	[Parameter(Mandatory = $true, ParameterSetName = 'Static')]
	[ValidateNotNullOrEmpty()]
	[switch] $static
	,
	[Parameter(Mandatory = $true, ParameterSetName = 'Static')]
	[ValidateNotNullOrEmpty()]
	[string] $DODNSSuffix
	,
	[Parameter(Mandatory = $true, ParameterSetName = 'Static')]
	[ValidateNotNullOrEmpty()]
	[string] $DOgateway
	,
	[Parameter(Mandatory = $true, ParameterSetName = 'Static')]
	[ValidateNotNullOrEmpty()]
	[string] $DOipAddress
	,
	[Parameter(Mandatory = $true, ParameterSetName = 'Static')]
	[ValidateNotNullOrEmpty()]
	[string] $DOStaticDNS1
	,
	[Parameter(Mandatory = $true, ParameterSetName = 'Static')]
	[ValidateNotNullOrEmpty()]
	[string] $DOStaticDNS2
	,
	[Parameter(Mandatory = $true, ParameterSetName = 'Static')]
	[ValidateNotNullOrEmpty()]
	[string] $DOsubnetMask
	,
	[Parameter(Mandatory = $false, ParameterSetName = 'Static')]
	[ValidateNotNullOrEmpty()]
	[string] $AdapterID = '0'

)
	
$datBegin = [datetime]::Now;
[string] $fn = $MyInvocation.MyCommand.Name;
Log-Debug -fn $fn -msg ("Call");

try{
	
	# Set IP Mode based on switch parameters
	if( $dhcp )
	{
		Log-Debug -fn $fn -msg ("DHCP");
		$IpAddressMode = "DHCP"
	} 
	else 
	{
		Log-Debug -fn $fn -msg ("Static");
		$IpAddressMode = "Static"
	}
	
	Log-Debug -fn $fn -msg ('Connect to SCCM Site: {0}' -f $SCCMSiteCode)
	Enter-Site -SiteCode $SCCMSiteCode

	Log-Debug -fn $fn -msg ('Init SCCM ComputerInformationVariables: ComputerName:{0}, MacAddress:{1}, CollectionName:{2}' -f $ActiveDirectoryComputerName, $MacAddress, $TargetCollectionName)
	Import-CMComputerInformation -ComputerName $ActiveDirectoryComputerName -MacAddress $MacAddress -CollectionName $TargetCollectionName -Confirm:$false
	
	Log-Debug -fn $fn -msg ('Import SCCM CMDeviceVariable: ComputerName:{0}, MacAddress:{1}' -f $ActiveDirectoryComputerName,$MacAddress)
	Add-SCCMOSDDeviceVariables -ActiveDirectoryComputerName $ActiveDirectoryComputerName -OperatingSystem $OperatingSystem -EmailAddress $EmailAddress -NetworkSpeed $NetworkSpeed -Trend $Trend -ApplicationTree $ApplicationTree -ApplicationProfile $ApplicationProfile -IpAddressMode $IpAddressMode -BypassChooser $BypassChooser -ComputerDomain $ComputerDomain -CumulusWindowsFeatures $CumulusWindowsFeatures
	
	#There are some additional properties required for static staging
	if( $static)
	{
		Log-Debug -fn $fn -msg ('Import SCCM CMDeviceVariable for static IP Mode: ComputerName:{0}, MacAddress:{1}' -f $ActiveDirectoryComputerName, $MacAddress)
		Add-SCCMAdditionalStaticIPModeOSDDeviceVariables -ActiveDirectoryComputerName $ActiveDirectoryComputerName -DODNSSuffix $DODNSSuffix -DOgateway $DOgateway -DOipAddress $DOipAddress -DOStaticDNS1 $DOStaticDNS1 -DOStaticDNS2 $DOStaticDNS2 -DOsubnetMask $DOsubnetMask -AdapterID $AdapterID

	}
	
	Log-Debug -fn $fn -msg ('Get CMDevice for ComputerName:{0}, MacAddress:{1}' -f $ActiveDirectoryComputerName,$MacAddress)
	
	$CMDevice = $null;
	$maxRetry = 120;
	$retryCount = 0;
	$sleepSec = 10
	while( ($null -eq $CMDevice) -and ( $retryCount -lt $maxRetry) )
	{
		
		$CMDevice = Get-CMDevice -Name $ActiveDirectoryComputerName
		if( $null -ne $CMDevice )
		{
			Log-Debug -fn $fn -msg ( "CMdevice Object successfully retrieved: {0} SMSID: {1}" -f $CMDevice.Name, $CMDevice.SMSID )
		} 
		else 
		{
			Log-Debug -fn $fn -msg ( "CMdevice Object not retrieved: {0} - Waiting for {1} Seconds. RetryAttempt {2}" -f $ActiveDirectoryComputerName, $sleepSec, $retryCount )
			$retryCount++;
			Start-Sleep $sleepSec
		}
		
	}
	
	Log-Debug -fn $fn -msg ('CMDevice Created: ComputerName:{0}, MacAddress:{1}, ResourceID: {2}' -f $ActiveDirectoryComputerName,$MacAddress, $CMDevice.ResourceID)
	
	if($null -eq $CMDevice)
	{
		throw ( "{0} Unable to retrieve CMDevice - retryCount: {1} -SleepSec: {2} - exiting" -f $ActiveDirectoryComputerName, $retryCount, $sleepSec );
	}
	
	return $CMDevice;

} 
catch 
{

	Log-Error -fn $fn -msg  ( "{0} Error occurred during SCCMRegisterVM: {1}" -f $ActiveDirectoryComputerName, $_.Exception.Message )
	throw $_.Exception
	
}

} # function

if($MyInvocation.ScriptName) { Export-ModuleMember -Function Register-VirtualMachine; } 


# SIG # Begin signature block
# MIIW3AYJKoZIhvcNAQcCoIIWzTCCFskCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQURwARSlFdJF+X/QXEHONHaSeF
# +7egghGYMIIEFDCCAvygAwIBAgILBAAAAAABL07hUtcwDQYJKoZIhvcNAQEFBQAw
# VzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNV
# BAsTB1Jvb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw0xMTA0
# MTMxMDAwMDBaFw0yODAxMjgxMjAwMDBaMFIxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMSgwJgYDVQQDEx9HbG9iYWxTaWduIFRpbWVzdGFt
# cGluZyBDQSAtIEcyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAlO9l
# +LVXn6BTDTQG6wkft0cYasvwW+T/J6U00feJGr+esc0SQW5m1IGghYtkWkYvmaCN
# d7HivFzdItdqZ9C76Mp03otPDbBS5ZBb60cO8eefnAuQZT4XljBFcm05oRc2yrmg
# jBtPCBn2gTGtYRakYua0QJ7D/PuV9vu1LpWBmODvxevYAll4d/eq41JrUJEpxfz3
# zZNl0mBhIvIG+zLdFlH6Dv2KMPAXCae78wSuq5DnbN96qfTvxGInX2+ZbTh0qhGL
# 2t/HFEzphbLswn1KJo/nVrqm4M+SU4B09APsaLJgvIQgAIMboe60dAXBKY5i0Eex
# +vBTzBj5Ljv5cH60JQIDAQABo4HlMIHiMA4GA1UdDwEB/wQEAwIBBjASBgNVHRMB
# Af8ECDAGAQH/AgEAMB0GA1UdDgQWBBRG2D7/3OO+/4Pm9IWbsN1q1hSpwTBHBgNV
# HSAEQDA+MDwGBFUdIAAwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFs
# c2lnbi5jb20vcmVwb3NpdG9yeS8wMwYDVR0fBCwwKjAooCagJIYiaHR0cDovL2Ny
# bC5nbG9iYWxzaWduLm5ldC9yb290LmNybDAfBgNVHSMEGDAWgBRge2YaRQ2XyolQ
# L30EzTSo//z9SzANBgkqhkiG9w0BAQUFAAOCAQEATl5WkB5GtNlJMfO7FzkoG8IW
# 3f1B3AkFBJtvsqKa1pkuQJkAVbXqP6UgdtOGNNQXzFU6x4Lu76i6vNgGnxVQ380W
# e1I6AtcZGv2v8Hhc4EvFGN86JB7arLipWAQCBzDbsBJe/jG+8ARI9PBw+DpeVoPP
# PfsNvPTF7ZedudTbpSeE4zibi6c1hkQgpDttpGoLoYP9KOva7yj2zIhd+wo7AKvg
# IeviLzVsD440RZfroveZMzV+y5qKu0VN5z+fwtmK+mWybsd+Zf/okuEsMaL3sCc2
# SI8mbzvuTXYfecPlf5Y1vC0OzAGwjn//UYCAp5LUs0RGZIyHTxZjBzFLY7Df8zCC
# BCgwggMQoAMCAQICCwQAAAAAAS9O4TVcMA0GCSqGSIb3DQEBBQUAMFcxCzAJBgNV
# BAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290
# IENBMRswGQYDVQQDExJHbG9iYWxTaWduIFJvb3QgQ0EwHhcNMTEwNDEzMTAwMDAw
# WhcNMTkwNDEzMTAwMDAwWjBRMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFs
# U2lnbiBudi1zYTEnMCUGA1UEAxMeR2xvYmFsU2lnbiBDb2RlU2lnbmluZyBDQSAt
# IEcyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsk8U5xC+1yZyqzaX
# 71O/QoReWNGKKPxDRm9+KERQC3VdANc8CkSeIGqk90VKN2Cjbj8S+m36tkbDaqO4
# DCcoAlco0VD3YTlVuMPhJYZSPL8FHdezmviaJDFJ1aKp4tORqz48c+/2KfHINdAw
# e39OkqUGj4fizvXBY2asGGkqwV67Wuhulf87gGKdmcfHL2bV/WIaglVaxvpAd47J
# MDwb8PI1uGxZnP3p1sq0QB73BMrRZ6l046UIVNmDNTuOjCMMdbbehkqeGj4KUEk4
# nNKokL+Y+siMKycRfir7zt6prjiTIvqm7PtcYXbDRNbMDH4vbQaAonRAu7cf9DvX
# c1Qf8wIDAQABo4H6MIH3MA4GA1UdDwEB/wQEAwIBBjASBgNVHRMBAf8ECDAGAQH/
# AgEAMB0GA1UdDgQWBBQIbti2nIq/7T7Xw3RdzIAfqC9QejBHBgNVHSAEQDA+MDwG
# BFUdIAAwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFsc2lnbi5jb20v
# cmVwb3NpdG9yeS8wMwYDVR0fBCwwKjAooCagJIYiaHR0cDovL2NybC5nbG9iYWxz
# aWduLm5ldC9yb290LmNybDATBgNVHSUEDDAKBggrBgEFBQcDAzAfBgNVHSMEGDAW
# gBRge2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0BAQUFAAOCAQEAIlzF3T30
# C3DY4/XnxY4JAbuxljZcWgetx6hESVEleq4NpBk7kpzPuUImuztsl+fHzhFtaJHa
# jW3xU01UOIxh88iCdmm+gTILMcNsyZ4gClgv8Ej+fkgHqtdDWJRzVAQxqXgNO4yw
# cME9fte9LyrD4vWPDJDca6XIvmheXW34eNK+SZUeFXgIkfs0yL6Erbzgxt0Y2/PK
# 8HvCFDwYuAO6lT4hHj9gaXp/agOejUr58CgsMIRe7CZyQrFty2TDEozWhEtnQXyx
# Axd4CeOtqLaWLaR+gANPiPfBa1pGFc0sGYvYcJzlLUmIYHKopBlScENe2tZGA7Bo
# DiTvSvYLJSTvJDCCBJ8wggOHoAMCAQICEhEhQFwfDtJYiCvlTYaGuhHqRTANBgkq
# hkiG9w0BAQUFADBSMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBu
# di1zYTEoMCYGA1UEAxMfR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcgQ0EgLSBHMjAe
# Fw0xMzA4MjMwMDAwMDBaFw0yNDA5MjMwMDAwMDBaMGAxCzAJBgNVBAYTAlNHMR8w
# HQYDVQQKExZHTU8gR2xvYmFsU2lnbiBQdGUgTHRkMTAwLgYDVQQDEydHbG9iYWxT
# aWduIFRTQSBmb3IgTVMgQXV0aGVudGljb2RlIC0gRzEwggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQCwF66i07YEMFYeWA+x7VWk1lTL2PZzOuxdXqsl/Tal
# +oTDYUDFRrVZUjtCoi5fE2IQqVvmc9aSJbF9I+MGs4c6DkPw1wCJU6IRMVIobl1A
# cjzyCXenSZKX1GyQoHan/bjcs53yB2AsT1iYAGvTFVTg+t3/gCxfGKaY/9Sr7KFF
# WbIub2Jd4NkZrItXnKgmK9kXpRDSRwgacCwzi39ogCq1oV1r3Y0CAikDqnw3u7sp
# Tj1Tk7Om+o/SWJMVTLktq4CjoyX7r/cIZLB6RA9cENdfYTeqTmvT0lMlnYJz+iz5
# crCpGTkqUPqp0Dw6yuhb7/VfUfT5CtmXNd5qheYjBEKvAgMBAAGjggFfMIIBWzAO
# BgNVHQ8BAf8EBAMCB4AwTAYDVR0gBEUwQzBBBgkrBgEEAaAyAR4wNDAyBggrBgEF
# BQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFsc2lnbi5jb20vcmVwb3NpdG9yeS8wCQYD
# VR0TBAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDBCBgNVHR8EOzA5MDegNaAz
# hjFodHRwOi8vY3JsLmdsb2JhbHNpZ24uY29tL2dzL2dzdGltZXN0YW1waW5nZzIu
# Y3JsMFQGCCsGAQUFBwEBBEgwRjBEBggrBgEFBQcwAoY4aHR0cDovL3NlY3VyZS5n
# bG9iYWxzaWduLmNvbS9jYWNlcnQvZ3N0aW1lc3RhbXBpbmdnMi5jcnQwHQYDVR0O
# BBYEFNSihEo4Whh/uk8wUL2d1XqH1gn3MB8GA1UdIwQYMBaAFEbYPv/c477/g+b0
# hZuw3WrWFKnBMA0GCSqGSIb3DQEBBQUAA4IBAQACMRQuWFdkQYXorxJ1PIgcw17s
# LOmhPPW6qlMdudEpY9xDZ4bUOdrexsn/vkWF9KTXwVHqGO5AWF7me8yiQSkTOMjq
# IRaczpCmLvumytmU30Ad+QIYK772XU+f/5pI28UFCcqAzqD53EvDI+YDj7S0r1tx
# KWGRGBprevL9DdHNfV6Y67pwXuX06kPeNT3FFIGK2z4QXrty+qGgk6sDHMFlPJET
# iwRdK8S5FhvMVcUM6KvnQ8mygyilUxNHqzlkuRzqNDCxdgCVIfHUPaj9oAAy126Y
# PKacOwuDvsu4uyomjFm4ua6vJqziNKLcIQ2BCzgT90Wj49vErKFtG7flYVzXMIIE
# rTCCA5WgAwIBAgISESFgd9/aXcgt4FtCBtsrp6UyMA0GCSqGSIb3DQEBBQUAMFEx
# CzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMScwJQYDVQQD
# Ex5HbG9iYWxTaWduIENvZGVTaWduaW5nIENBIC0gRzIwHhcNMTIwNjA4MDcyNDEx
# WhcNMTUwNzEyMTAzNDA0WjB6MQswCQYDVQQGEwJERTEbMBkGA1UECBMSU2NobGVz
# d2lnLUhvbHN0ZWluMRAwDgYDVQQHEwdJdHplaG9lMR0wGwYDVQQKDBRkLWZlbnMg
# R21iSCAmIENvLiBLRzEdMBsGA1UEAwwUZC1mZW5zIEdtYkggJiBDby4gS0cwggEi
# MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDTG4okWyOURuYYwTbGGokj+lvB
# go0dwNYJe7HZ9wrDUUB+MsPTTZL82O2INMHpQ8/QEMs87aalzHz2wtYN1dUIBUae
# dV7TZVme4ycjCfi5rlL+p44/vhNVnd1IbF/pxu7yOwkAwn/iR+FWbfAyFoCThJYk
# 9agPV0CzzFFBLcEtErPJIvrHq94tbRJTqH9sypQfrEToe5kBWkDYfid7U0rUkH/m
# bff/Tv87fd0mJkCfOL6H7/qCiYF20R23Kyw7D2f2hy9zTcdgzKVSPw41WTsQtB3i
# 05qwEZ3QCgunKfDSCtldL7HTdW+cfXQ2IHItN6zHpUAYxWwoyWLOcWcS69InAgMB
# AAGjggFUMIIBUDAOBgNVHQ8BAf8EBAMCB4AwTAYDVR0gBEUwQzBBBgkrBgEEAaAy
# ATIwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFsc2lnbi5jb20vcmVw
# b3NpdG9yeS8wCQYDVR0TBAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzA+BgNVHR8E
# NzA1MDOgMaAvhi1odHRwOi8vY3JsLmdsb2JhbHNpZ24uY29tL2dzL2dzY29kZXNp
# Z25nMi5jcmwwUAYIKwYBBQUHAQEERDBCMEAGCCsGAQUFBzAChjRodHRwOi8vc2Vj
# dXJlLmdsb2JhbHNpZ24uY29tL2NhY2VydC9nc2NvZGVzaWduZzIuY3J0MB0GA1Ud
# DgQWBBTwJ4K6WNfB5ea1nIQDH5+tzfFAujAfBgNVHSMEGDAWgBQIbti2nIq/7T7X
# w3RdzIAfqC9QejANBgkqhkiG9w0BAQUFAAOCAQEAB3ZotjKh87o7xxzmXjgiYxHl
# +L9tmF9nuj/SSXfDEXmnhGzkl1fHREpyXSVgBHZAXqPKnlmAMAWj0+Tm5yATKvV6
# 82HlCQi+nZjG3tIhuTUbLdu35bss50U44zNDqr+4wEPwzuFMUnYF2hFbYzxZMEAX
# Vlnaj+CqtMF6P/SZNxFvaAgnEY1QvIXI2pYVz3RhD4VdDPmMFv0P9iQ+npC1pmNL
# mCaG7zpffUFvZDuX6xUlzvOi0nrTo9M5F2w7LbWSzZXedam6DMG0nR1Xcx0qy9wY
# nq4NsytwPbUy+apmZVSalSvldiNDAfmdKP0SCjyVwk92xgNxYFwITJuNQIto4zGC
# BK4wggSqAgEBMGcwUTELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24g
# bnYtc2ExJzAlBgNVBAMTHkdsb2JhbFNpZ24gQ29kZVNpZ25pbmcgQ0EgLSBHMgIS
# ESFgd9/aXcgt4FtCBtsrp6UyMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQow
# CKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcC
# AQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQqejdqYjmpGuYONCSb
# jmM0oyM0BDANBgkqhkiG9w0BAQEFAASCAQBD2RrjadQUobFY2NAFjvEgTZCekiQE
# uwncnmReGt1AqaYCW+tlDGwvcLFXYxDcbtJTyBLqdige78w2eZHTVGGzJ/FXBCfm
# UX9dH9TWi8cEZzEsUcEJX2LFhBXxeZic5CsnHcLWbG34bxAv0d67ZmhNyXfFrbNT
# qMFZV5/dargoDctx/IfB88VghnCPc3tW+Gh7tO8t7+7ScEuSjLt34vjvbnTfAMNk
# SpgqLdRWphjiNC5tn9DU94L1aDu85J0Wn1xAz05TZ5JprRQb+b89lhN1ZQWMoQP8
# 8f7edhhpSzWVjI8M67rySQEzUc99nU8BYtKRpSJiaKJWFz7QnAi0Nma9oYICojCC
# Ap4GCSqGSIb3DQEJBjGCAo8wggKLAgEBMGgwUjELMAkGA1UEBhMCQkUxGTAXBgNV
# BAoTEEdsb2JhbFNpZ24gbnYtc2ExKDAmBgNVBAMTH0dsb2JhbFNpZ24gVGltZXN0
# YW1waW5nIENBIC0gRzICEhEhQFwfDtJYiCvlTYaGuhHqRTAJBgUrDgMCGgUAoIH9
# MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE0MTEy
# NzEyMzAzOVowIwYJKoZIhvcNAQkEMRYEFB05eja41vBomayUGPzNTIyvmxQiMIGd
# BgsqhkiG9w0BCRACDDGBjTCBijCBhzCBhAQUjOafUBLh0aj7OV4uMeK0K947NDsw
# bDBWpFQwUjELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2Ex
# KDAmBgNVBAMTH0dsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gRzICEhEhQFwf
# DtJYiCvlTYaGuhHqRTANBgkqhkiG9w0BAQEFAASCAQA3C2kbbra1oAC34knwjMFO
# XOeGuiEdgHSAu9rUn4fs1ZLJIHkllrnVG8gJkXFxvelQR/rxTHrjWKfMNVLWZjVz
# 7bOzrFeS6q0hHCg9tja/CFkHYDawZdL2gSLRwXMeSV/Hu1QziEO8jIckJmRg23nK
# RSFfss/YJWfxHCH54N4fv5FyRy2cYZbtbjdPQ/5ZpVXeaC6FrS8byeKj9nt40zOt
# us3rDwEtsbn/1guSsgP7PsNM/YVe9wPqHmRXMTsobjayvtAHyD41SmQUUA2FOwJi
# aqaqAKTDbMYHimHNN4/7UHve4uLQoG5FUxxkQnW9zLG29No7W4bs+nFNMrKUUfOY
# SIG # End signature block
