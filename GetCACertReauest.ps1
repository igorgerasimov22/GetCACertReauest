Import-Module PSPKI

$CAServer = "ServerCAName"
$EmailFrom = "ca-monitor@domain.com"
$EmailTo = "recipient@domain.com"
$SMTPServer = "mail.domain.com"
$SMTPPort = 25
$EmailSubject = "Оповещение: Новые сертификаты ожидают подтверждения в CA"

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    $pendingRequestsRaw = Get-PendingRequest -CertificationAuthority $CAServer

    $pendingRequests = @()
    foreach ($req in $pendingRequestsRaw) {
        $request = [PSCustomObject]@{
            RequestID = $req.RequestID
            RequesterName = $req.'Request.RequesterName'
            RequestTime = $req.'Request.SubmittedWhen'
            Template = ($req.CertificateTemplateOid).FriendlyName
            SubjectName = $req.'Request.CommonName'
        }
        $pendingRequests += $request
    }
} catch {
    Write-Error "Ошибка при получении списка запросов сертификатов: $($_.Exception.Message)"
    exit 1
}

if ($pendingRequests.Count -eq 0) {
    #Write-Host "Нет сертификатов в статусе 'Ожидает подтверждения'"
    exit 0
}

$htmlBody = @"
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <style>
        body { font-family: Arial, sans-serif; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h2>Сертификаты в статусе «Ожидает подтверждения»</h2>
    <p>Найдено <strong>$($pendingRequests.Count)</strong> запросов, требующих подтверждения.</p>
    <table>
        <thead>
            <tr>
                <th>ID запроса</th>
                <th>Запрашивающий</th>
                <th>Время запроса</th>
                <th>Шаблон сертификата</th>
                <th>Субъект</th>
            </tr>
        </thead>
        <tbody>
"@

foreach ($request in $pendingRequests) {
    $subject = if ($request.SubjectName) { $request.SubjectName } else { "Не указан" }
    $template = if ($request.Template) { $request.Template } else { "Не указан" }

    $htmlBody += @"
            <tr>
                <td>$($request.RequestID)</td>
                <td>$($request.RequesterName)</td>
                <td>$($request.RequestTime)</td>
                <td>$template</td>
                <td>$subject</td>
            </tr>
"@
}

$htmlBody += @"
        </tbody>
    </table>
    <br>
    <p><em>Автоматическое уведомление от системы мониторинга CA</em></p>
</body>
</html>
"@

try {
    $mailParams = @{
        From = $EmailFrom
        To = $EmailTo
        Subject = $EmailSubject
        Body = $htmlBody
        BodyAsHtml = $true
        SmtpServer = $SMTPServer
        Port = $SMTPPort
        Encoding = [System.Text.Encoding]::UTF8
    }
    Send-MailMessage @mailParams
    #Write-Host "Уведомление отправлено на $($EmailTo -join ', ')"
} catch {
    #Write-Error "Ошибка при отправке email: $($_.Exception.Message)"
    exit 1
}
