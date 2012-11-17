New-Variable `
	-Name 'XMLRPCTypeMapping' `
	-Value @{
		[string]	= 'string';
		[int]		= 'int';
		[long]		= 'int';
		[double]	= 'double';
		[float]		= 'double';
		[bool]		= 'boolean';
		[DateTime]	= 'dateTime.iso8601';
	} `
	-Option Constant `
;

function Invoke-API {
	<#
		.Component
			XMLRPC клиент
		.Synopsis
			Вызов метода через XMLRPC интерфейс.
		.Description
			Вызов метода через XMLRPC интерфейс.
			По интерфейсу данный командлет близок к Invoke-Command. Следует предварительно сгенерировать 
			прокси функцию к Invoke-Command, и уже затем её и дорабатывать.
		.Link
			[Wikipedia - XMLRPC](http://wikipedia.org/wiki/XML-RPC)
		.Example
			Invoke-API;
	#>

	[CmdletBinding(
		SupportsShouldProcess=$true,
		ConfirmImpact='Medium'
	)]
	
	param (
		# url точки подключения к XMLRPC сервису
		[Parameter(
			Mandatory=$true
		)]
		[System.Uri[]]
		[ValidateNotNullOrEmpty()]
		[Alias('Uri')]
		[Alias('CU')]
		$ConnectionUri
	)
};

function ConvertTo-XmlRpcString([object]$value) {
	if($value -is [Hashtable]) {
		return [string]::Join([Environment]::NewLine,
(&{ @"
<struct>
"@
$value.GetEnumerator() | % { $name=$_.Key; $value=(ConvertTo-XmlRpcString $_.Value); @"
  <member>
    <name>$name</name>
    <value>
      $value
    </value>
  </member>
"@ }
@"
</struct>
"@ })
)
	} elseif($value -is [Array]) {
		return [string]::Join([Environment]::NewLine,
(&{ @"
<array>
  <data>
"@
$value | % { $value=(ConvertTo-XmlRpcString $_); @"
    <value>
      $value
    </value>
"@ }
@"
  </data>
</array>
"@ })
)
	} else {
		return "<{0}>{1}</{0}>" -f $xmlTypeMapping[$value.GetType()], (& {
			if($value -is [DateTime]) { return $value.ToString('yyyyMMddTHH:mm:ss') }
			else {
				return $value
			}
		})
	}
}

$reqXml = &{ @"
<?xml version="1.0" encoding="UTF-8"?>
<methodCall>
  <methodName>$methodName</methodName>
  <params>
"@
$arguments | % { $value=(ConvertTo-XmlRpcString $_); @"
    <param>
      <value>
        $value
      </value>
    </param>
"@ }
@"
  </params>
</methodCall>
"@ }; Write-Debug [string]$reqXml

$content = [Text.Encoding]::UTF8.GetBytes($reqXml)

$httpReq = [Net.HttpWebRequest]::Create($reqURL)
$httpReq.Method = "POST"
$httpReq.UserAgent = "Mozilla/4.0 (compatible; MSIE 6.0; Windows XP)"
$httpReq.ContentType = "text/xml"
$httpReq.ContentLength = $content.Length

$reqStream = $httpReq.GetRequestStream()
$reqStream.Write($content, 0, $content.Length)
$reqStream.Close()

$httpRes = $httpReq.GetResponse()
if($httpRes.StatusCode -ne "OK") {
	Write-Error "The problem occurred while acquiring the response."
	exit 1
}
$resStream = $httpRes.GetResponseStream()
$resXml = [xml]((New-Object IO.StreamReader($resStream)).ReadToEnd())
$resStream.Close()

$resXml

Export-ModuleMember `
	Invoke-API `
;