Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
Install-Module -Name SqlServer
Install-Module -Name AzureAd
Install-Module -Name Az.Accounts
Install-Module -Name Az.Sql
Install-Module -Name Microsoft.Graph
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
