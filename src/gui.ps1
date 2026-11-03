$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$C=@{bg='#100c27'; side='#16112f'; panel='#1d1536'; border='#4c3d75'; ink='#f7f3ff'; muted='#b6a8d1'; accent='#7454ff'; green='#6be0ae'}
function Color([string]$x) { [Drawing.ColorTranslator]::FromHtml($x) }
function Label($parent,$text,$x,$y,$w,$h,$size,$color,$bold=$false) {
 $v=New-Object Windows.Forms.Label; $v.Text=$text; $v.SetBounds($x,$y,$w,$h); $v.ForeColor=Color $color; $v.BackColor=[Drawing.Color]::Transparent; $style=if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}; $v.Font=New-Object Drawing.Font('Segoe UI',[float]$size,$style); $parent.Controls.Add($v); return $v
}
function PixelRegion($v) {
 $w=$v.Width; $h=$v.Height; $p=New-Object Drawing.Drawing2D.GraphicsPath; [Drawing.Point[]]$points=@((New-Object Drawing.Point(4,0)),(New-Object Drawing.Point(($w-4),0)),(New-Object Drawing.Point(($w-4),4)),(New-Object Drawing.Point($w,4)),(New-Object Drawing.Point($w,($h-4))),(New-Object Drawing.Point(($w-4),($h-4))),(New-Object Drawing.Point(($w-4),$h)),(New-Object Drawing.Point(4,$h)),(New-Object Drawing.Point(4,($h-4))),(New-Object Drawing.Point(0,($h-4))),(New-Object Drawing.Point(0,4)),(New-Object Drawing.Point(4,4))); $p.AddPolygon($points); $v.Region=New-Object Drawing.Region($p); $p.Dispose()
}
function Button($parent,$text,$x,$y,$w,$h,$fill,$fg) {
 $v=New-Object Windows.Forms.Button; $v.Text=$text; $v.SetBounds($x,$y,$w,$h); $v.FlatStyle='Flat'; $v.FlatAppearance.BorderSize=1; $v.FlatAppearance.BorderColor=Color $C.border; $v.FlatAppearance.MouseOverBackColor=Color '#544098'; $v.BackColor=Color $fill; $v.ForeColor=Color $fg; $v.Font=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold); $v.Cursor=[Windows.Forms.Cursors]::Hand; PixelRegion $v; $parent.Controls.Add($v); return $v
}
$form=New-Object Windows.Forms.Form; $form.Text='Horizon Privacy Patcher'; $form.FormBorderStyle='None'; $form.ClientSize=New-Object Drawing.Size(1040,670); $form.StartPosition='CenterScreen'; $form.BackColor=Color $C.bg; $form.Font=New-Object Drawing.Font('Segoe UI',10); $form.KeyPreview=$true
$form.Add_KeyDown({ if ($_.KeyCode -eq 'Escape' -and -not $script:busy) { $form.Close() } })
$bar=New-Object Windows.Forms.Panel; $bar.SetBounds(0,0,1040,34); $bar.BackColor=Color '#0a071b'; $form.Controls.Add($bar)
[void](Label $bar '✣' 16 5 22 24 12 $C.ink $true); [void](Label $bar 'Horizon Privacy Patcher' 41 8 280 22 9 $C.muted)
$min=Button $bar '—' 958 0 40 33 '#0a071b' $C.muted; $close=Button $bar '×' 999 0 40 33 '#0a071b' $C.muted; $min.FlatAppearance.BorderSize=0; $close.FlatAppearance.BorderSize=0
$min.Add_Click({$form.WindowState='Minimized'}); $close.Add_Click({if(-not $script:busy){$form.Close()}})
$bar.Add_MouseDown({ if ($_.Button -eq 'Left') { $script:drag=$true; $script:dragX=$_.X; $script:dragY=$_.Y } }); $bar.Add_MouseUp({$script:drag=$false}); $bar.Add_MouseMove({if($script:drag){$p=[Windows.Forms.Cursor]::Position; $form.Location=New-Object Drawing.Point(($p.X-$script:dragX),($p.Y-$script:dragY))}})
$side=New-Object Windows.Forms.Panel; $side.SetBounds(0,34,218,636); $side.BackColor=Color $C.side; $form.Controls.Add($side)
[void](Label $side 'ИНСТРУМЕНТ' 17 18 175 22 8 $C.muted $true)
$nav=New-Object Windows.Forms.Panel; $nav.SetBounds(10,46,198,50); $nav.BackColor=Color '#28204a'; PixelRegion $nav; $side.Controls.Add($nav)
[void](Label $nav 'H' 11 8 32 34 19 $C.ink $true); [void](Label $nav 'Патчер Horizon' 51 8 135 22 10 $C.ink $true); [void](Label $nav '■  Windows' 51 29 120 16 8 $C.green)
[void](Label $side 'ЧТО МЕНЯЕТСЯ' 17 133 175 22 8 $C.muted $true)
[void](Label $side '■  Вход необязателен' 17 164 185 23 9 $C.ink); [void](Label $side '■  Без телеметрии Horizon' 17 194 195 23 9 $C.ink); [void](Label $side '■  Автообновление патча' 17 224 195 23 9 $C.ink)
[void](Label $side 'Неофициальный проект' 17 562 180 21 9 $C.muted); $version=Label $side $env:HORIZON_PATCHER_TAG 17 586 190 31 8 $C.muted
$main=New-Object Windows.Forms.Panel; $main.SetBounds(218,34,822,636); $main.BackColor=Color '#110c2a'; $form.Controls.Add($main)
$main.Add_Paint({param($sender,$e)
 $g=$e.Graphics; function PaintRect($c,$x,$y,$w,$h){$b=New-Object Drawing.SolidBrush((Color $c));$g.FillRectangle($b,$x,$y,$w,$h);$b.Dispose()}
 PaintRect '#100c27' 0 0 822 54; PaintRect '#171038' 0 54 822 62; PaintRect '#1c1045' 0 116 822 72; PaintRect '#281449' 0 188 822 66; PaintRect '#381a50' 0 254 822 65; PaintRect '#54245d' 0 319 822 62; PaintRect '#75316c' 0 381 822 48; PaintRect '#9e4978' 0 429 822 52; PaintRect '#c35f78' 0 481 822 46; PaintRect '#ed886d' 0 527 822 109
 PaintRect '#ffd28a' 552 494 56 5; PaintRect '#ffd28a' 535 499 90 7; PaintRect '#ffdf9a' 519 506 123 9; PaintRect '#ffdf9a' 505 515 150 12; PaintRect '#ffdf9a' 493 527 174 13
 PaintRect '#2d1c4e' 0 576 100 60; PaintRect '#2d1c4e' 100 587 108 49; PaintRect '#2d1c4e' 208 572 97 64; PaintRect '#2d1c4e' 305 593 110 43; PaintRect '#2d1c4e' 415 583 112 53; PaintRect '#2d1c4e' 527 590 95 46; PaintRect '#2d1c4e' 622 576 107 60; PaintRect '#2d1c4e' 729 588 93 48
 PaintRect '#100c27' 0 611 160 25; PaintRect '#100c27' 160 616 180 20; PaintRect '#100c27' 340 608 140 28; PaintRect '#100c27' 480 617 160 19; PaintRect '#100c27' 640 606 182 30
 foreach($x in @(78,273,485,685,773)){PaintRect '#100c27' $x 562 7 65; PaintRect '#100c27' ($x-9) 575 25 6}
 foreach($x in @(180,400,628)){PaintRect '#100c27' $x 582 6 38; PaintRect '#100c27' ($x-7) 571 20 15; PaintRect '#100c27' ($x-3) 566 12 5}
 PaintRect '#ffbf66' 505 528 150 5; PaintRect '#ff944f' 493 535 174 5
 foreach($p in @(@(120,70),@(260,115),@(535,93),@(660,125),@(740,73),@(360,165),@(580,194),@(98,215))){PaintRect '#9180b3' $p[0] $p[1] 1 1}
 PaintRect '#5b3b7e' 504 211 120 3; PaintRect '#5b3b7e' 525 208 77 3; PaintRect '#874b83' 682 281 100 3; PaintRect '#874b83' 699 278 65 3
})
[void](Label $main '■  PRIVACY PATCHER · WINDOWS' 34 17 400 22 8 $C.green $true)
$mark=New-Object Windows.Forms.Panel; $mark.SetBounds(34,52,53,53); $mark.BackColor=Color '#161320'; PixelRegion $mark; $main.Controls.Add($mark); $mark.Add_Paint({param($sender,$e) $b=New-Object Drawing.SolidBrush((Color '#f4f0ff')); $a=New-Object Drawing.SolidBrush((Color '#8b73ff')); $e.Graphics.FillRectangle($b,13,8,6,35); $e.Graphics.FillRectangle($b,34,8,6,35); $e.Graphics.FillRectangle($a,3,23,47,4); $a.Dispose(); $b.Dispose() })
[void](Label $main 'Horizon' 99 45 490 58 30 $C.ink $true)
[void](Label $main 'Патчер приватности' 36 113 500 25 11 $C.ink $true)
[void](Label $main 'Выберите лаунчер, чтобы применить изменения.' 36 143 700 28 10 $C.muted)
$card=New-Object Windows.Forms.Panel; $card.SetBounds(34,196,752,237); $card.BackColor=Color $C.panel; PixelRegion $card; $main.Controls.Add($card)
[void](Label $card 'Лаунчер Horizon' 20 17 360 27 11 $C.ink $true)
[void](Label $card 'Найденные файлы' 20 48 360 20 9 $C.muted)
$refresh=Button $card 'Обновить' 620 19 112 32 '#2c214b' $C.ink
$list=New-Object Windows.Forms.ListBox; $list.SetBounds(20,76,712,69); $list.BorderStyle='None'; $list.BackColor=Color '#110d27'; $list.ForeColor=Color $C.ink; $list.Font=New-Object Drawing.Font('Segoe UI',10); $list.IntegralHeight=$false; $list.DrawMode='OwnerDrawFixed'; $list.ItemHeight=34; $card.Controls.Add($list)
$list.Add_DrawItem({param($sender,$e) if($e.Index -lt 0){return}; $selected=($e.State -band [Windows.Forms.DrawItemState]::Selected) -ne 0; $bg=if($selected){'#37285c'}else{'#110d27'}; $brush=New-Object Drawing.SolidBrush((Color $bg)); $e.Graphics.FillRectangle($brush,$e.Bounds); $brush.Dispose(); $rect=New-Object Drawing.Rectangle(($e.Bounds.X+12),$e.Bounds.Y,($e.Bounds.Width-24),$e.Bounds.Height); $flags=[Windows.Forms.TextFormatFlags]::Left -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::EndEllipsis; [Windows.Forms.TextRenderer]::DrawText($e.Graphics,[string]$sender.Items[$e.Index],$sender.Font,$rect,(Color $C.ink),$flags) })
$browse=Button $card 'Выбрать вручную' 20 165 191 47 '#2a2048' $C.ink
$apply=Button $card '▶  Применить патч' 507 165 225 47 $C.accent $C.ink; $apply.Enabled=$false
$statusBox=New-Object Windows.Forms.Panel; $statusBox.SetBounds(34,449,752,77); $statusBox.BackColor=Color '#1b1433'; PixelRegion $statusBox; $main.Controls.Add($statusBox)
$statusTitle=Label $statusBox 'ПОИСК ЛАУНЧЕРА' 20 12 700 22 9 $C.ink $true
$status=Label $statusBox 'Ищем лаунчер в стандартных папках…' 20 37 710 34 10 $C.ink

$script:busy=$false; $script:worker=$null; $script:kind=''; $script:outTask=$null; $script:errTask=$null
function SetBusy([bool]$value) { $script:busy=$value; $refresh.Enabled=-not $value; $browse.Enabled=-not $value; $list.Enabled=-not $value; $apply.Enabled=(-not $value -and $list.SelectedIndex -ge 0) }
function StartWorker([string]$kind,[string]$target='') {
    if ($script:busy) { return }
    $script:kind=$kind; SetBusy $true
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
        if ($exit -ne 0) { $statusTitle.Text='ОШИБКА ПОИСКА'; $status.Text=$err }
        elseif ($list.Items.Count -gt 0) { $list.SelectedIndex=0; $statusTitle.Text='ГОТОВО'; $status.Text='Выберите лаунчер и закройте его перед применением патча.' }
        else { $statusTitle.Text='ЛАУНЧЕР НЕ НАЙДЕН'; $status.Text='Выберите файл horizon-launcher.exe вручную.' }
    } elseif ($exit -eq 0) { $statusTitle.Text='ГОТОВО'; $status.Text='Патч применён. Проверка обновлений настроена каждый час.' }
    else { $statusTitle.Text='НЕ УДАЛОСЬ ЗАВЕРШИТЬ'; if ($err -match 'Unsupported or modified') { $status.Text='Неизвестная или изменённая версия лаунчера. Файл не изменён.' } elseif ($err -match 'Close the selected launcher') { $status.Text='Закройте лаунчер и попробуйте ещё раз.' } else { $status.Text=$err } }
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
