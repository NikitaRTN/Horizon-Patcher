$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$C=@{bg='#0b0817'; panel='#171127'; inner='#100c1d'; border='#373047'; ink='#f7f5ff'; muted='#aaa1c4'; accent='#6e56ff'; green='#84dfbc'}
function Color([string]$x) { [Drawing.ColorTranslator]::FromHtml($x) }
function Label($parent,$text,$x,$y,$w,$h,$size,$color,$bold=$false) {
    $v=New-Object Windows.Forms.Label; $v.Text=$text; $v.SetBounds($x,$y,$w,$h); $v.ForeColor=Color $color; $v.BackColor=[Drawing.Color]::Transparent
    $style=if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}; $v.Font=New-Object Drawing.Font('Segoe UI',[float]$size,$style); $parent.Controls.Add($v); return $v
}
function Round($control,[int]$radius) {
    $w=$control.Width; $h=$control.Height; $d=$radius*2; $p=New-Object Drawing.Drawing2D.GraphicsPath
    $p.AddArc(0,0,$d,$d,180,90); $p.AddArc(($w-$d),0,$d,$d,270,90); $p.AddArc(($w-$d),($h-$d),$d,$d,0,90); $p.AddArc(0,($h-$d),$d,$d,90,90); $p.CloseFigure()
    $control.Region=New-Object Drawing.Region($p); $p.Dispose()
}
function Button($parent,$text,$x,$y,$w,$h,$fill,$fg) {
    $v=New-Object Windows.Forms.Button; $v.Text=$text; $v.SetBounds($x,$y,$w,$h); $v.FlatStyle='Flat'; $v.FlatAppearance.BorderSize=0; $v.FlatAppearance.MouseOverBackColor=Color '#44375c'; $v.BackColor=Color $fill; $v.ForeColor=Color $fg; $v.Font=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold); $v.Cursor=[Windows.Forms.Cursors]::Hand; Round $v 8; $parent.Controls.Add($v); return $v
}
function Card($parent,$x,$y,$w,$h) { $p=New-Object Windows.Forms.Panel; $p.SetBounds($x,$y,$w,$h); $p.BackColor=Color $C.panel; Round $p 14; $parent.Controls.Add($p); return $p }
function Sky([int]$w,[int]$h) {
    $bmp=New-Object Drawing.Bitmap($w,$h); $g=[Drawing.Graphics]::FromImage($bmp)
    $r=New-Object Drawing.Rectangle(0,0,$w,$h); $gradient=New-Object Drawing.Drawing2D.LinearGradientBrush($r,(Color '#0b0817'),(Color '#edb46f'),[Drawing.Drawing2D.LinearGradientMode]::Vertical)
    $blend=New-Object Drawing.Drawing2D.ColorBlend; $blend.Positions=[single[]]@(0,.38,.62,.76,.87,1); $blend.Colors=[Drawing.Color[]]@((Color '#0b0817'),(Color '#110c24'),(Color '#22133d'),(Color '#4c2159'),(Color '#8a3b64'),(Color '#edb46f')); $gradient.InterpolationColors=$blend; $g.FillRectangle($gradient,$r); $gradient.Dispose()
    $rng=New-Object Random(813); $star=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(100,205,192,255)); for($i=0;$i -lt 90;$i++){ $x=$rng.Next(12,$w-12); $y=$rng.Next(72,($h-140)); $g.FillRectangle($star,$x,$y,2,2) }; $star.Dispose()
    $sun=New-Object Drawing.SolidBrush((Color '#f9ca87')); $cx=780; $base=$h-190
    foreach($band in @(@(-35,0,70,8),@(-53,10,106,10),@(-65,22,130,12),@(-72,36,144,14),@(-75,53,150,14),@(-70,72,140,8),@(-60,85,120,6))){$g.FillRectangle($sun,($cx+$band[0]),($base+$band[1]),$band[2],$band[3])}; $sun.Dispose()
    $cloud=New-Object Drawing.SolidBrush((Color '#6d376c')); foreach($c in @(@(70,100,130),@(245,80,145),@(660,120,200),@(850,92,140))){$g.FillRectangle($cloud,$c[0],($h-$c[1]),$c[2],6)}; $cloud.Dispose()
    $hill=New-Object Drawing.SolidBrush((Color '#231138')); $g.FillRectangle($hill,0,($h-65),$w,65); foreach($c in @(@(0,50,180),@(190,43,150),@(610,50,210),@(860,68,180))){$g.FillRectangle($hill,$c[0],($h-$c[1]),$c[2],$c[1])}; $hill.Dispose()
    $front=New-Object Drawing.SolidBrush((Color '#120921')); $g.FillRectangle($front,0,($h-25),$w,25); foreach($x in @(24,310,420,850,985)){$g.FillRectangle($front,$x,($h-57),6,42); $g.FillRectangle($front,($x-10),($h-43),26,6); $g.FillRectangle($front,($x-6),($h-51),18,6)}; $g.Dispose(); return $bmp
}
$form=New-Object Windows.Forms.Form; $form.Text='Horizon Privacy Patcher'; $form.FormBorderStyle='FixedSingle'; $form.MaximizeBox=$false; $form.ClientSize=New-Object Drawing.Size(1040,660); $form.StartPosition='CenterScreen'; $form.BackColor=Color $C.bg; $form.BackgroundImage=Sky 1040 660; $form.Font=New-Object Drawing.Font('Segoe UI',10); $form.KeyPreview=$true
$form.Add_KeyDown({if ($_.KeyCode -eq 'Escape' -and -not $script:busy) { $form.Close() }})
$header=New-Object Windows.Forms.Panel; $header.SetBounds(0,0,1040,60); $header.BackColor=Color '#0c0918'; $form.Controls.Add($header)
[void](Label $header 'H' 32 15 28 30 16 '#a793ff' $true)
[void](Label $header 'Horizon' 62 18 85 26 11 $C.ink $true)
[void](Label $header 'PRIVACY PATCHER' 153 21 190 23 9 '#a793ff' $true)
[void](Label $header 'WINDOWS  •  PORTABLE' 806 21 220 22 9 $C.muted $true)
[void](Label $form 'HORIZON LAUNCHER  /  WINDOWS X64' 42 102 500 22 9 '#b5add1' $true)
[void](Label $form 'Лаунчер, который вы знаете,' 40 141 560 42 23 $C.ink $true)
[void](Label $form 'без лишней телеметрии.' 40 181 560 42 23 '#a793ff' $true)
[void](Label $form 'Выберите лаунчер, закройте его и примените патч.' 42 234 540 24 10 $C.muted)
$card=Card $form 42 285 525 260
[void](Label $card '01  /  ВЫБОР ЛАУНЧЕРА' 20 17 310 20 9 '#a793ff' $true)
[void](Label $card 'Выберите файл Horizon' 20 42 340 29 13 $C.ink $true)
$refresh=Button $card 'Обновить' 388 22 117 36 '#30283f' $C.ink
[void](Label $card 'Выберите horizon-launcher.exe, а не установщик.' 20 76 480 22 9 $C.muted)
$list=New-Object Windows.Forms.ListBox; $list.SetBounds(20,105,485,67); $list.BorderStyle='None'; $list.BackColor=Color $C.inner; $list.ForeColor=Color $C.ink; $list.Font=New-Object Drawing.Font('Segoe UI',10); $list.IntegralHeight=$false; $list.DrawMode='OwnerDrawFixed'; $list.ItemHeight=31; $card.Controls.Add($list)
$list.Add_DrawItem({param($sender,$e) if($e.Index -lt 0){return}; $selected=($e.State -band [Windows.Forms.DrawItemState]::Selected) -ne 0; $bg=if($selected){'#352953'}else{'#100c1d'}; $brush=New-Object Drawing.SolidBrush((Color $bg)); $e.Graphics.FillRectangle($brush,$e.Bounds); $brush.Dispose(); if($selected){$b=New-Object Drawing.SolidBrush((Color $C.accent)); $e.Graphics.FillRectangle($b,$e.Bounds.X,$e.Bounds.Y,4,$e.Bounds.Height);$b.Dispose()}; $rect=New-Object Drawing.Rectangle(($e.Bounds.X+14),$e.Bounds.Y,($e.Bounds.Width-28),$e.Bounds.Height); $flags=[Windows.Forms.TextFormatFlags]::Left -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::EndEllipsis; [Windows.Forms.TextRenderer]::DrawText($e.Graphics,[string]$sender.Items[$e.Index],$sender.Font,$rect,(Color $C.ink),$flags); if(($e.State -band [Windows.Forms.DrawItemState]::Focus) -ne 0){$e.DrawFocusRectangle()} })
$apply=Button $card 'Применить патч' 20 192 201 47 $C.accent $C.ink; $apply.FlatAppearance.MouseOverBackColor=Color '#826dff'; $apply.Enabled=$false
$browse=Button $card 'Выбрать вручную' 233 192 190 47 '#30283f' $C.ink
$releaseCard=Card $form 600 127 398 418
[void](Label $releaseCard 'СОВМЕСТИМАЯ ВЕРСИЯ' 24 23 340 22 9 '#a793ff' $true)
$compatibleVersion=$env:HORIZON_PATCHER_VERSION
$expectedSetup='https://github.com/horizon-rust/horizon/releases/download/launcher%40'+$compatibleVersion+'/horizon-launcher-setup.exe'
$hasCompatibleSetup=($compatibleVersion -cmatch '^[0-9]+\.[0-9]+\.[0-9]+$' -and $env:HORIZON_SETUP_URL -ceq $expectedSetup)
$compatibleText=if($hasCompatibleSetup){'Horizon '+$compatibleVersion+'  /  x64'}else{'Версия не определена'}
$compatibleLabel=Label $releaseCard $compatibleText 24 54 350 34 16 $C.ink $true
[void](Label $releaseCard 'Официальный установщик без изменений' 24 94 350 24 9 $C.muted)
$download=Button $releaseCard 'Скачать установщик' 24 130 350 48 '#6e56ff' $C.ink; $download.FlatAppearance.MouseOverBackColor=Color '#826dff'; $download.Enabled=$hasCompatibleSetup
[void](Label $releaseCard '02  /  СТАТУС' 24 212 350 22 9 '#a793ff' $true)
$statusTitle=Label $releaseCard 'ПОИСК ЛАУНЧЕРА' 24 242 350 25 10 $C.green $true
$status=Label $releaseCard 'Ищем лаунчер в стандартных папках…' 24 275 350 80 10 $C.ink
[void](Label $releaseCard 'Проверка файла перед применением' 24 374 350 22 9 $C.muted)
[void](Label $form 'Windows x64    •    Резервная копия    •    Неофициальный проект' 42 572 730 24 9 '#d0c6e2')
$tip=New-Object Windows.Forms.ToolTip
$list.Add_SelectedIndexChanged({if($list.SelectedIndex -ge 0){$tip.SetToolTip($list,[string]$list.SelectedItem)}})
function OpenOfficialSetup {
    if (-not $hasCompatibleSetup) { return }
    try { Start-Process -FilePath $env:HORIZON_SETUP_URL | Out-Null }
    catch { $statusTitle.Text='ОШИБКА'; $statusTitle.ForeColor=Color '#ffb398'; $status.Text='Не удалось открыть ссылку на установщик: '+$_.Exception.Message }
}
$download.Add_Click({ OpenOfficialSetup })

$script:busy=$false; $script:worker=$null; $script:kind=''; $script:outTask=$null; $script:errTask=$null
function SetBusy([bool]$value) { $script:busy=$value; $refresh.Enabled=-not $value; $browse.Enabled=-not $value; $list.Enabled=-not $value; $apply.Enabled=(-not $value -and $list.SelectedIndex -ge 0) }
function StartWorker([string]$kind,[string]$target='') {
    if ($script:busy) { return }
    $script:kind=$kind; $statusTitle.ForeColor=Color $C.green; SetBusy $true
    if ($kind -eq 'scan') { $statusTitle.Text='ПОИСК ЛАУНЧЕРА'; $status.Text='Ищем лаунчер в стандартных папках…'; $arguments='--scan' }
    else { $statusTitle.Text='ПРИМЕНЕНИЕ ПАТЧА'; $status.Text='Проверяем файл и настраиваем обновления…'; $arguments='--install "'+$target+'"' }
    try {
        $info=New-Object Diagnostics.ProcessStartInfo; $info.FileName=$env:HORIZON_PATCHER_EXE; $info.Arguments=$arguments; $info.UseShellExecute=$false; $info.CreateNoWindow=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true; $info.StandardOutputEncoding=[Text.Encoding]::UTF8; $info.StandardErrorEncoding=[Text.Encoding]::UTF8; $info.EnvironmentVariables.Remove('HORIZON_GUI_SCRIPT')
        $script:worker=New-Object Diagnostics.Process; $script:worker.StartInfo=$info; [void]$script:worker.Start(); $script:outTask=$script:worker.StandardOutput.ReadToEndAsync(); $script:errTask=$script:worker.StandardError.ReadToEndAsync(); $timer.Start()
    } catch { SetBusy $false; $statusTitle.Text='ОШИБКА'; $status.Text='Не удалось запустить проверку: '+$_.Exception.Message }
}
$timer=New-Object Windows.Forms.Timer; $timer.Interval=150
$timer.Add_Tick({
    if (-not $script:worker.HasExited) { return }
    $timer.Stop(); $exit=$script:worker.ExitCode; $output=$script:outTask.Result.Trim(); $err=$script:errTask.Result.Trim(); $script:worker.Dispose(); $script:worker=$null
    if ($script:kind -eq 'scan') {
        $list.Items.Clear()
        if ($exit -eq 0) {
            try { $paths=@($output | ConvertFrom-Json); foreach($p in $paths) { if ($p) { [void]$list.Items.Add([string]$p) } } } catch { $exit=1; $err=$_.Exception.Message }
        }
        if ($exit -ne 0) { $statusTitle.Text='ОШИБКА ПОИСКА'; $statusTitle.ForeColor=Color '#ffb398'; $status.Text=$err }
        elseif ($list.Items.Count -gt 0) { $list.SelectedIndex=0; $statusTitle.Text='ГОТОВО'; $status.Text='Выберите лаунчер и закройте его перед применением патча.' }
        else { $statusTitle.Text='ЛАУНЧЕР НЕ НАЙДЕН'; $status.Text='Выберите файл horizon-launcher.exe вручную.' }
    } elseif ($exit -eq 0) { $statusTitle.Text='ГОТОВО'; $status.Text='Патч применён. Обновления проверяются при запуске патчера.' }
    else { $statusTitle.Text='НЕ УДАЛОСЬ ЗАВЕРШИТЬ'; $statusTitle.ForeColor=Color '#ffb398'; if ($err -match 'Unsupported or modified') { $status.Text='Неизвестная или изменённая версия лаунчера. Файл не изменён.' } elseif ($err -match 'Close the selected launcher') { $status.Text='Закройте лаунчер и попробуйте ещё раз.' } else { $status.Text=$err } }
    SetBusy $false
})
$list.Add_SelectedIndexChanged({ if (-not $script:busy) { $apply.Enabled=($list.SelectedIndex -ge 0) } })
$refresh.Add_Click({ StartWorker 'scan' })
$browse.Add_Click({
    $dialog=New-Object Windows.Forms.OpenFileDialog; $dialog.Title='Выберите лаунчер Horizon'; $dialog.Filter='Приложения (*.exe)|*.exe|Все файлы (*.*)|*.*'; $dialog.CheckFileExists=$true
    try { if ($dialog.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK) { $i=$list.Items.IndexOf($dialog.FileName); if ($i -lt 0) { $i=$list.Items.Add($dialog.FileName) }; $list.SelectedIndex=$i; $statusTitle.Text='ГОТОВО'; $status.Text='Закройте лаунчер перед применением патча.' } } finally { $dialog.Dispose() }
})
$apply.Add_Click({ if ($list.SelectedIndex -ge 0) { StartWorker 'install' ([string]$list.SelectedItem) } })
$form.Add_Shown({ StartWorker 'scan' })
[Windows.Forms.Application]::Run($form)
