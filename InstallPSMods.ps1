Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
Install-Module -Name SqlServer
Install-Module -Name Az
Install-Module -Name Microsoft.Graph
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
