<#
============================================================================================================================
Script: Show-WingetInfo
Author: Smart Ace Designs

Notes:
This script displays a Windows Forms GUI for showing Winget information.
============================================================================================================================
#>

#region Settings
$REQUIRED_MODULES = @("Microsoft.WinGet.Client")
$SUPPORT_CONTACT = "Smart Ace Designs"
#endregion

#region Assemblies
Add-Type -AssemblyName System.Windows.Forms
#endregion

#region Appearance
[System.Windows.Forms.Application]::EnableVisualStyles()
#endregion

#region Controls
$FormMain = New-Object -TypeName System.Windows.Forms.Form
$GroupBoxMain = New-Object -TypeName System.Windows.Forms.GroupBox
$LabelApps = New-Object -TypeName System.Windows.Forms.Label
$DataGridViewApps = New-Object -TypeName System.Windows.Forms.DataGridView
$CheckBoxOutdated = New-Object -TypeName System.Windows.Forms.CheckBox
$ButtonRun = New-Object -TypeName System.Windows.Forms.Button
$ButtonClose = New-Object -TypeName System.Windows.Forms.Button
$StatusStripMain = New-Object -TypeName System.Windows.Forms.StatusStrip
$ToolStripStatusLabelMain = New-Object -TypeName System.Windows.Forms.ToolStripStatusLabel
#endregion

#region Forms
$ShowFormMain =
{
    $FormWidth = 800
    $FormHeight = 380

    $FormMain.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Process -Id $PID).Path)
    $FormMain.Text = "Winget Tool"
    $FormMain.Font = New-Object -TypeName System.Drawing.Font("MS Sans Serif",8)
    $FormMain.ClientSize = New-Object -TypeName System.Drawing.Size($FormWidth,$FormHeight)
    $FormMain.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $FormMain.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $FormMain.MaximizeBox = $false
    $FormMain.AcceptButton = $ButtonRun
    $FormMain.CancelButton = $ButtonClose
    $FormMain.Add_Shown($FormMain_Shown)

    $GroupBoxMain.Location = New-Object -TypeName System.Drawing.Point(10,5)
    $GroupBoxMain.Size = New-Object -TypeName System.Drawing.Size(($FormWidth - 20),($FormHeight - 80))
    $FormMain.Controls.Add($GroupBoxMain)

    $LabelApps.Location = New-Object -TypeName System.Drawing.Point(15,15)
    $LabelApps.AutoSize = $true
    $LabelApps.Text = "Installed Applications:"
    $GroupBoxMain.Controls.Add($LabelApps)
    
    $DataGridViewApps.Location = New-Object -TypeName System.Drawing.Point(15,35)
    $DataGridViewApps.Size = New-Object -TypeName System.Drawing.Size(($FormWidth - 50),($FormHeight - 135))
    $DataGridViewApps.TabStop = $false
    $DataGridViewApps.RowTemplate.Height = 20
    $DataGridViewApps.DataBindings.DefaultDataSourceUpdateMode = [System.Windows.Forms.DataSourceUpdateMode]::OnValidation
    $DataGridViewApps.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $DataGridViewApps.RowHeadersVisible = $false
    $DataGridViewApps.AllowUserToResizeRows = $false
    $DataGridViewApps.ReadOnly = $true
    $DataGridViewApps.AllowUserToAddRows = $false
    $DataGridViewApps.AllowUserToDeleteRows = $false
    $DataGridViewApps.ColumnCount = 3
    $DataGridViewApps.ColumnHeadersVisible = $true
    $DataGridViewApps.Columns[0].Name = "Application Name"
    $DataGridViewApps.Columns[1].Name = "Installed Version"
    $DataGridViewApps.Columns[2].Name = "Update Available"
    $GroupBoxMain.Controls.Add($DataGridViewApps)

    $CheckBoxOutdated.Location = New-Object -TypeName System.Drawing.Point(15,($FormHeight - 60))
    $CheckBoxOutdated.Text = "Outdated Applications"
    $CheckBoxOutdated.AutoSize = $true
    $CheckBoxOutdated.Add_CheckedChanged($CheckBoxOutdated_CheckedChanged)
    $FormMain.Controls.Add($CheckBoxOutdated)

    $ButtonRun.Location = New-Object -TypeName System.Drawing.Point(($FormWidth - 175),($FormHeight - 60))
    $ButtonRun.Size = New-Object -TypeName System.Drawing.Size(75,25)
    $ButtonRun.TabIndex = 100
    $ButtonRun.Enabled = $false
    $ButtonRun.Text = "Refresh"
    $ButtonRun.Add_Click($ButtonRun_Click)
    $FormMain.Controls.Add($ButtonRun)

    $ButtonClose.Location = New-Object -TypeName System.Drawing.Point(($FormWidth - 85),($FormHeight - 60))
    $ButtonClose.Size = New-Object -TypeName System.Drawing.Size(75,25)
    $ButtonClose.TabIndex = 101
    $ButtonClose.Text = "Close"
    $ButtonClose.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $FormMain.Controls.Add($ButtonClose)

    $StatusStripMain.SizingGrip = $false
    $StatusStripMain.Font = New-Object -TypeName System.Drawing.Font("MS Sans Serif",8)
    [void]$StatusStripMain.Items.Add($ToolStripStatusLabelMain)
    $FormMain.Controls.Add($StatusStripMain)

    [void]$FormMain.ShowDialog()
    $FormMain.Dispose()
}
#endregion

#region Functions
function Invoke-FormAction
{
    param
    (
        [Parameter(Mandatory, Position = 0)] [ScriptBlock]$Action,
        [Parameter(Position = 1)] [ScriptBlock]$Reset = $null
    )

    try
    {
        $ToolStripStatusLabelMain.Text = "Working...please wait"
        $FormMain.Controls | Where-Object {$PSItem -isnot [System.Windows.Forms.StatusStrip]} | ForEach-Object {$PSItem.Enabled = $false}
        $FormMain.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        [System.Windows.Forms.Application]::DoEvents()
        Invoke-Command -ScriptBlock $Action
    }
    
    finally
    {
        $FormMain.Controls | ForEach-Object {$PSItem.Enabled = $true}
        $FormMain.ResetCursor()
        if ($Reset) {Invoke-Command -ScriptBlock $Reset}
        $ToolStripStatusLabelMain.Text = "Ready"
        $StatusStripMain.Update()
    }
}

function Get-WingetData
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0)] [switch]$UpdatesOnly
    )

    if ($UpdatesOnly) {$Apps = Get-WinGetPackage | Where-Object {$PSItem.IsUpdateAvailable} | Sort-Object Name | Select-Object Name, InstalledVersion, IsUpdateAvailable}
    else {$Apps = Get-WinGetPackage | Sort-Object Name | Select-Object Name, InstalledVersion, IsUpdateAvailable}

    if ($Apps)
    {
        $DataGridViewApps.Rows.Clear()
        $Apps | ForEach-Object {$DataGridViewApps.Rows.Add($PSItem.Name, $PSItem.InstalledVersion, $PSItem.IsUpdateAvailable)}
        
        foreach ($Column in $DataGridViewApps.Columns)
        {
            if ($Column.Index -eq 0)
            {
                $Column.AutoSizeMode = "AllCells"
                $Column.Width = $Column.Width
                $Column.AutoSizeMode = "None"
            }
            elseif ($Column.Index -eq $DataGridViewApps.Columns.Count - 1)
            {
                $Column.AutoSizeMode = "Fill"
            }
            else
            {
                $Column.AutoSizeMode = "AllCells"
                $Column.Width = $Column.Width
                $Column.AutoSizeMode = "None"
            }
        }
        $ButtonRun.Enabled = $true
        $FormMain.Refresh()
    }
    else
    {
        $Message = "Winget is not installed or no packages found."
        if ($CheckBoxOutdated.Checked) {$Message = "All applications are at the latest version."}

        $ToolStripStatusLabelMain.Text = $Message
        $StatusStripMain.Update()
        [void][System.Windows.Forms.MessageBox]::Show(
            $Message,
            "Information",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information)
        $CheckBoxOutdated.Checked = $false
    }
}
#endregion

#region Handlers
$FormMain_Shown =
{
    Invoke-FormAction -Action {
        try
        {
            Get-WingetData
        }
        catch
        {
            [void][System.Windows.Forms.MessageBox]::Show(
                $PSItem.Exception.Message + "`n`nPlease contact $SUPPORT_CONTACT for technical support.",
                "Exception",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        }
    }
}

$ButtonRun_Click =
{
    Invoke-FormAction -Action {
        try
        {
            if ($CheckBoxOutdated.Checked) {Get-WingetData -UpdatesOnly}
            else {Get-WingetData}
        }
        catch
        {
            [void][System.Windows.Forms.MessageBox]::Show(
                $PSItem.Exception.Message + "`n`nPlease contact $SUPPORT_CONTACT for technical support.",
                "Exception",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        }
    }
}

$CheckBoxOutdated_CheckedChanged =
{
    Invoke-FormAction -Action {
        try
        {
            if ($CheckBoxOutdated.Checked) {Get-WingetData -UpdatesOnly}
            else {Get-WingetData}
        }
        catch
        {
            [void][System.Windows.Forms.MessageBox]::Show(
                $PSItem.Exception.Message + "`n`nPlease contact $SUPPORT_CONTACT for technical support.",
                "Exception",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        }
    }
}
#endregion

#region Main
$MissingModules = @()
foreach ($Module in $REQUIRED_MODULES)
{
    if ($REQUIRED_MODULES -notcontains $(Get-Module -ListAvailable -Name $Module | Get-Unique)) {$MissingModules += $(" $([char]8226) " + $Module)}
}

if ($MissingModules)
{
    [void][System.Windows.Forms.MessageBox]::Show(
        "The following PowerShell modules are required:`n`n$($MissingModules -join `"`n`")`n`nPlease contact $SUPPORT_CONTACT for technical support.",
        "Requirements",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}
else
{
    Invoke-Command -ScriptBlock $ShowFormMain
}
#endregion
