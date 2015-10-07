Push-Location $PSScriptRoot

Add-Type -Path .\tools\HtmlAgilityPack.dll

$tempDir = ".\temp"

if (!(Test-Path $tempDir)) {
    md $tempDir | Out-Null
}

function DownloadElasticsearch {
    $ErrorActionPreference = "Stop"
    
    $doc = New-Object HtmlAgilityPack.HtmlDocument

    $WebResponse = Invoke-WebRequest "https://www.elastic.co/downloads/elasticsearch"

    $doc.LoadHtml($WebResponse.Content)

    $url = $doc.DocumentNode.SelectSingleNode("//a[starts-with(@class, 'zip-link')]");

    $downloadUrl =  "https://download.elasticsearch.org/elasticsearch/release/org/elasticsearch/distribution/zip/elasticsearch/2.0.0-rc1/elasticsearch-2.0.0-rc1.zip"
    #New-Object System.Uri -ArgumentList @($url.Attributes["href"].Value)
    
    Write-Host "Downloading " $downloadUrl


    $bak = $ProgressPreference 
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest $downloadUrl -UseBasicParsing -UseDefaultCredentials -WebSession $s -OutFile .\temp\es.zip
    $ProgressPreference = $bak
    Write-Host "done." -ForegroundColor Green

    Write-Host "Extracting Elasticsearch..."


    
    .\tools\7z.exe x .\temp\es.zip -otemp\
    
    Write-Host "done." -ForegroundColor Green

}

function DownloadJre{
    $ErrorActionPreference = "Stop"
        
    
    $doc = New-Object HtmlAgilityPack.HtmlDocument
    $WebResponse = Invoke-WebRequest "http://www.oracle.com/technetwork/java/javase/downloads/jre8-downloads-2133155.html"
    $doc.LoadHtml($WebResponse.Content)

    $lines = $doc.DocumentNode.InnerText -split '\r\n?|\n\r?'

    $jreLine = $lines| Where { $_.Contains("windows-x64.tar.gz") } | Select -First 1

    $jreLine = $jreLine.Substring($jreLine.IndexOf("http"), ($jreLine.LastIndexOf(".tar.gz")+7)-$jreLine.IndexOf("http"))

    $downloadUrl =  New-Object System.Uri -ArgumentList @($jreLine)
    
    Write-Host "Downloading " $downloadUrl

    $downloadPage = 'http://www.oracle.com/'

    $bak = $ProgressPreference 
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest $downloadPage -UseBasicParsing -UseDefaultCredentials -SessionVariable s | Out-Null
    $c = New-Object System.Net.Cookie("oraclelicense", "accept-securebackup-cookie", "/", ".oracle.com")
    $s.Cookies.Add($downloadPage, $c)
    Invoke-WebRequest $downloadUrl -UseBasicParsing -UseDefaultCredentials -WebSession $s -OutFile .\temp\jre.tgz
    $ProgressPreference = $bak
    Write-Host "done." -ForegroundColor Green

    Write-Host "Extracting Java ..."

    .\tools\7z.exe x .\temp\jre.tgz -otemp\
    .\tools\7z.exe x .\temp\*.tar -otemp\
}



if ($Host.Version.Major -lt 3) {
    throw "Powershell v3 or greater is required."
}

Remove-Item ..\source\ElasticsearchInside\Executables\*.lz4


DownloadJre

$jreDir = Get-ChildItem -Recurse $directory | Where-Object { $_.PSIsContainer -and `
    $_.Name.StartsWith("jre") } | Select-Object -First 1

Write-Host "Encoding file " $jreDir.Fullname
.\tools\LZ4Encoder.exe  $jreDir.Fullname ..\source\ElasticsearchInside\Executables\jre.lz4


DownloadElasticsearch
$elasticDir = Get-ChildItem -Recurse $directory | Where-Object { $_.PSIsContainer -and `
    $_.Name.StartsWith("elasticsearch") } | Select-Object -First 1

Write-Host "Encoding file " $elasticDir.Fullname

.\tools\LZ4Encoder.exe $elasticDir.Fullname ..\source\ElasticsearchInside\Executables\elasticsearch.lz4


Remove-Item temp -Force -Recurse 

