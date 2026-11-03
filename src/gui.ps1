$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$C=@{bg='#0e0a22'; side='#14102d'; panel='#1c1536'; border='#493b6e'; ink='#f9f6ff'; muted='#b6a8d1'; accent='#7454ff'; green='#74dfb6'}
function Color([string]$x) { [Drawing.ColorTranslator]::FromHtml($x) }
function Label($parent,$text,$x,$y,$w,$h,$size,$color,$bold=$false) {
 $v=New-Object Windows.Forms.Label; $v.Text=$text; $v.SetBounds($x,$y,$w,$h); $v.ForeColor=Color $color; $v.BackColor=[Drawing.Color]::Transparent; $style=if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}; $v.Font=New-Object Drawing.Font('Segoe UI',[float]$size,$style); $parent.Controls.Add($v); return $v
}
function PixelRegion($v) {
 $w=$v.Width; $h=$v.Height; $p=New-Object Drawing.Drawing2D.GraphicsPath; [Drawing.Point[]]$points=@((New-Object Drawing.Point(4,0)),(New-Object Drawing.Point(($w-4),0)),(New-Object Drawing.Point(($w-4),4)),(New-Object Drawing.Point($w,4)),(New-Object Drawing.Point($w,($h-4))),(New-Object Drawing.Point(($w-4),($h-4))),(New-Object Drawing.Point(($w-4),$h)),(New-Object Drawing.Point(4,$h)),(New-Object Drawing.Point(4,($h-4))),(New-Object Drawing.Point(0,($h-4))),(New-Object Drawing.Point(0,4)),(New-Object Drawing.Point(4,4))); $p.AddPolygon($points); $v.Region=New-Object Drawing.Region($p); $p.Dispose()
}
function Button($parent,$text,$x,$y,$w,$h,$fill,$fg) {
 $v=New-Object Windows.Forms.Button; $v.Text=$text; $v.SetBounds($x,$y,$w,$h); $v.FlatStyle='Flat'; $v.FlatAppearance.BorderSize=1; $v.FlatAppearance.BorderColor=Color $C.border; $v.FlatAppearance.MouseOverBackColor=Color '#584598'; $v.BackColor=Color $fill; $v.ForeColor=Color $fg; $v.Font=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold); $v.Cursor=[Windows.Forms.Cursors]::Hand; PixelRegion $v; $parent.Controls.Add($v); return $v
}
function Mark($parent,$x,$y,$size) {
 $v=New-Object Windows.Forms.Panel; $v.SetBounds($x,$y,$size,$size); $v.BackColor=Color '#11101f'; PixelRegion $v; $parent.Controls.Add($v)
 $v.Add_Paint({param($sender,$e) $n=$sender.Width; $white=New-Object Drawing.SolidBrush((Color '#f8f6ff')); $violet=New-Object Drawing.SolidBrush((Color '#8b72ff')); $e.Graphics.FillRectangle($white,[int]($n*.25),[int]($n*.19),[int]($n*.11),[int]($n*.62)); $e.Graphics.FillRectangle($white,[int]($n*.64),[int]($n*.19),[int]($n*.11),[int]($n*.62)); $e.Graphics.FillRectangle($violet,[int]($n*.08),[int]($n*.46),[int]($n*.84),[Math]::Max(3,[int]($n*.08))); $white.Dispose(); $violet.Dispose()})
}
$form=New-Object Windows.Forms.Form; $form.Text='Horizon Privacy Patcher'; $form.FormBorderStyle='None'; $form.ClientSize=New-Object Drawing.Size(1040,670); $form.StartPosition='CenterScreen'; $form.BackColor=Color $C.bg; $form.Font=New-Object Drawing.Font('Segoe UI',10); $form.KeyPreview=$true
$form.Add_KeyDown({ if ($_.KeyCode -eq 'Escape' -and -not $script:busy) { $form.Close() } })
$bar=New-Object Windows.Forms.Panel; $bar.SetBounds(0,0,1040,34); $bar.BackColor=Color '#090719'; $form.Controls.Add($bar)
[void](Label $bar '✣' 16 5 22 24 12 $C.ink $true); [void](Label $bar 'Horizon Privacy Patcher' 41 8 280 22 9 $C.muted)
$min=Button $bar '—' 958 0 40 33 '#090719' $C.muted; $close=Button $bar '×' 999 0 40 33 '#090719' $C.muted; $min.FlatAppearance.BorderSize=0; $close.FlatAppearance.BorderSize=0
$min.Add_Click({$form.WindowState='Minimized'}); $close.Add_Click({if(-not $script:busy){$form.Close()}})
$bar.Add_MouseDown({ if ($_.Button -eq 'Left') { $script:drag=$true; $script:dragX=$_.X; $script:dragY=$_.Y } }); $bar.Add_MouseUp({$script:drag=$false}); $bar.Add_MouseMove({if($script:drag){$p=[Windows.Forms.Cursor]::Position; $form.Location=New-Object Drawing.Point(($p.X-$script:dragX),($p.Y-$script:dragY))}})
$side=New-Object Windows.Forms.Panel; $side.SetBounds(0,34,218,636); $side.BackColor=Color $C.side; $form.Controls.Add($side)
[void](Label $side 'HORIZON' 22 24 150 28 13 $C.ink $true); [void](Label $side 'PRIVACY PATCHER' 23 50 170 22 8 $C.muted $true)
[void](Label $side 'ПРИЛОЖЕНИЕ' 22 108 170 20 8 $C.muted $true)
$nav=New-Object Windows.Forms.Panel; $nav.SetBounds(12,134,194,56); $nav.BackColor=Color '#29204b'; PixelRegion $nav; $side.Controls.Add($nav)
Mark $nav 9 8 40; [void](Label $nav 'Патчер Horizon' 58 9 128 22 10 $C.ink $true); [void](Label $nav '■  Windows' 58 31 110 19 8 $C.green)
[void](Label $side 'ПОСЛЕ ПРИМЕНЕНИЯ' 22 238 185 22 8 $C.muted $true)
[void](Label $side '01' 22 270 28 23 9 '#8e78ed' $true); [void](Label $side 'Офлайн-профиль' 54 270 145 24 9 $C.ink)
[void](Label $side '02' 22 306 28 23 9 '#8e78ed' $true); [void](Label $side 'Телеметрия Horizon' 54 306 145 24 9 $C.ink)
[void](Label $side '03' 22 342 28 23 9 '#8e78ed' $true); [void](Label $side 'Проверка обновлений' 54 342 155 24 9 $C.ink)
[void](Label $side 'Неофициальный проект' 22 564 180 22 9 $C.muted); $version=Label $side $env:HORIZON_PATCHER_TAG 22 587 185 32 8 $C.muted
$main=New-Object Windows.Forms.Panel; $main.SetBounds(218,34,822,636); $main.BackColor=Color '#130e2a'; $form.Controls.Add($main)
$main.Add_Paint({param($sender,$e)
 $g=$e.Graphics; function PaintRect($c,$x,$y,$w,$h){$b=New-Object Drawing.SolidBrush((Color $c));$g.FillRectangle($b,$x,$y,$w,$h);$b.Dispose()}
 $rect=New-Object Drawing.Rectangle(0,0,822,636); $grad=New-Object Drawing.Drawing2D.LinearGradientBrush($rect,(Color '#110d28'),(Color '#522f65'),90); $g.FillRectangle($grad,$rect); $grad.Dispose()
 PaintRect '#120d27' 0 0 822 51; PaintRect '#403458' 0 50 822 1
 foreach($p in @(@(420,93),@(540,129),@(657,78),@(752,151),@(319,164),@(765,190),@(705,116),@(603,176),@(338,92))){PaintRect '#a995ca' $p[0] $p[1] 2 2}
 PaintRect '#5c366f' 0 527 822 22; PaintRect '#814477' 0 549 822 20; PaintRect '#b35c7b' 0 569 822 20; PaintRect '#e27d74' 0 589 822 47
 PaintRect '#ffdd9c' 557 540 52 6; PaintRect '#ffdd9c' 543 546 80 7; PaintRect '#ffdd9c' 531 553 104 8; PaintRect '#ffdd9c' 519 561 128 10; PaintRect '#ffdd9c' 508 571 150 12; PaintRect '#ffc383' 501 583 164 9
 PaintRect '#302052' 0 604 105 32; PaintRect '#302052' 105 612 91 24; PaintRect '#302052' 196 600 94 36; PaintRect '#302052' 290 615 112 21; PaintRect '#302052' 402 605 100 31; PaintRect '#302052' 502 616 112 20; PaintRect '#302052' 614 605 104 31; PaintRect '#302052' 718 613 104 23
 PaintRect '#110c27' 0 624 160 12; PaintRect '#110c27' 160 630 170 6; PaintRect '#110c27' 330 624 157 12; PaintRect '#110c27' 487 631 138 5; PaintRect '#110c27' 625 625 197 11
 foreach($x in @(72,258,472,688,768)){PaintRect '#110c27' $x 590 7 46; PaintRect '#110c27' ($x-8) 602 23 5}; foreach($x in @(150,360,590)){PaintRect '#110c27' $x 607 5 29; PaintRect '#110c27' ($x-7) 600 19 9}
})
[void](Label $main 'ПАТЧЕР  /  ГЛАВНАЯ' 34 15 340 22 8 $C.muted $true); [void](Label $main '■  WINDOWS  ·  PORTABLE' 620 15 180 20 8 $C.green $true)
Mark $main 34 76 54
[void](Label $main 'Horizon' 102 68 310 54 29 $C.ink $true)
[void](Label $main 'Патчер приватности' 104 120 375 25 10 $C.muted)
[void](Label $main 'Подготовьте лаунчер к игре без лишней телеметрии.' 34 148 710 24 10 $C.ink)
$card=New-Object Windows.Forms.Panel; $card.SetBounds(34,183,752,245); $card.BackColor=Color $C.panel; PixelRegion $card; $main.Controls.Add($card)
$card.Add_Paint({param($sender,$e) $p=New-Object Drawing.Pen((Color '#493961')); $e.Graphics.DrawRectangle($p,0,0,($sender.Width-1),($sender.Height-1)); $p.Dispose()})
[void](Label $card '01  /  ВЫБОР ЛАУНЧЕРА' 24 16 350 20 8 $C.muted $true)
[void](Label $card 'Выберите Horizon' 24 38 360 28 13 $C.ink $true)
[void](Label $card 'Найденные файлы' 24 70 350 20 9 $C.muted)
$refresh=Button $card '↻  Обновить' 596 28 132 38 '#292046' $C.ink
$list=New-Object Windows.Forms.ListBox; $list.SetBounds(24,97,704,66); $list.BorderStyle='None'; $list.BackColor=Color '#100c25'; $list.ForeColor=Color $C.ink; $list.Font=New-Object Drawing.Font('Segoe UI',10); $list.IntegralHeight=$false; $list.DrawMode='OwnerDrawFixed'; $list.ItemHeight=33; $card.Controls.Add($list)
$list.Add_DrawItem({param($sender,$e) if($e.Index -lt 0){return}; $selected=($e.State -band [Windows.Forms.DrawItemState]::Selected) -ne 0; $bg=if($selected){'#37295e'}else{'#100c25'}; $brush=New-Object Drawing.SolidBrush((Color $bg)); $e.Graphics.FillRectangle($brush,$e.Bounds); $brush.Dispose(); if($selected){$b=New-Object Drawing.SolidBrush((Color $C.accent)); $e.Graphics.FillRectangle($b,$e.Bounds.X,$e.Bounds.Y,4,$e.Bounds.Height);$b.Dispose()}; $rect=New-Object Drawing.Rectangle(($e.Bounds.X+16),$e.Bounds.Y,($e.Bounds.Width-30),$e.Bounds.Height); $flags=[Windows.Forms.TextFormatFlags]::Left -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::EndEllipsis; [Windows.Forms.TextRenderer]::DrawText($e.Graphics,[string]$sender.Items[$e.Index],$sender.Font,$rect,(Color $C.ink),$flags); if(($e.State -band [Windows.Forms.DrawItemState]::Focus) -ne 0){$e.DrawFocusRectangle()} })
$browse=Button $card 'Выбрать вручную…' 24 184 190 43 '#2a2048' $C.ink
$apply=Button $card 'Применить патч  →' 505 184 223 43 $C.accent $C.ink; $apply.FlatAppearance.BorderColor=Color '#9e8aff'; $apply.Enabled=$false
$statusBox=New-Object Windows.Forms.Panel; $statusBox.SetBounds(34,444,752,69); $statusBox.BackColor=Color '#18122f'; PixelRegion $statusBox; $main.Controls.Add($statusBox)
$statusBox.Add_Paint({param($sender,$e) $p=New-Object Drawing.Pen((Color '#40345d')); $e.Graphics.DrawRectangle($p,0,0,($sender.Width-1),($sender.Height-1)); $p.Dispose()})
$statusTitle=Label $statusBox 'ПОИСК ЛАУНЧЕРА' 20 10 700 19 8 $C.green $true
$status=Label $statusBox 'Ищем лаунчер в стандартных папках…' 20 31 710 31 10 $C.ink
$tip=New-Object Windows.Forms.ToolTip
$list.Add_SelectedIndexChanged({if($list.SelectedIndex -ge 0){$tip.SetToolTip($list,[string]$list.SelectedItem)}})

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
