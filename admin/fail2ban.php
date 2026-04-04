<?php include 'session.php'; ?>
<?php include 'functions.php'; ?>

<?php if (!checkPermissions()) {
    goHome();
} ?>

<?php
CoreUtilities::$rSettings = CoreUtilities::getSettings(true);
$rSettings = CoreUtilities::$rSettings;
$_TITLE = 'Fail2Ban Firewall';

// Handle POST actions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['action'])) {
        $rAction = $_POST['action'];
        $rIP = isset($_POST['ip']) ? preg_replace('/[^0-9\.\:]/', '', $_POST['ip']) : '';
        $rJail = isset($_POST['jail']) ? preg_replace('/[^a-zA-Z0-9\-]/', '', $_POST['jail']) : 'sshd';

        switch ($rAction) {
            case 'unban':
                if (!empty($rIP)) {
                    shell_exec("sudo fail2ban-client set " . escapeshellarg($rJail) . " unbanip " . escapeshellarg($rIP) . " 2>&1");
                    $_STATUS = 'success';
                    $_MESSAGE = "IP {$rIP} desbloqueado do jail {$rJail}";
                }
                break;
            case 'ban':
                if (!empty($rIP)) {
                    shell_exec("sudo fail2ban-client set " . escapeshellarg($rJail) . " banip " . escapeshellarg($rIP) . " 2>&1");
                    $_STATUS = 'success';
                    $_MESSAGE = "IP {$rIP} bloqueado no jail {$rJail}";
                }
                break;
            case 'start':
                shell_exec("sudo systemctl start fail2ban 2>&1");
                $_STATUS = 'success';
                $_MESSAGE = 'Fail2Ban iniciado';
                break;
            case 'stop':
                shell_exec("sudo systemctl stop fail2ban 2>&1");
                $_STATUS = 'warning';
                $_MESSAGE = 'Fail2Ban parado - servidor desprotegido!';
                break;
            case 'restart':
                shell_exec("sudo systemctl restart fail2ban 2>&1");
                $_STATUS = 'success';
                $_MESSAGE = 'Fail2Ban reiniciado';
                break;
            case 'unban_all':
                shell_exec("sudo fail2ban-client unban --all 2>&1");
                $_STATUS = 'success';
                $_MESSAGE = 'Todos os IPs foram desbloqueados';
                break;
            case 'save_config':
                $rBantime = intval($_POST['bantime'] ?? 86400);
                $rFindtime = intval($_POST['findtime'] ?? 600);
                $rMaxretry = intval($_POST['maxretry'] ?? 3);
                $rPort = intval($_POST['port'] ?? 2288);
                $rWhitelist = preg_replace('/[^0-9\.\,\s\/]/', '', $_POST['whitelist'] ?? '');

                $rConf = "[DEFAULT]\n";
                $rConf .= "bantime = {$rBantime}\n";
                $rConf .= "findtime = {$rFindtime}\n";
                $rConf .= "maxretry = {$rMaxretry}\n";
                $rConf .= "banaction = ufw\n";
                if (!empty(trim($rWhitelist))) {
                    $rConf .= "ignoreip = 127.0.0.1/8 ::1 " . trim($rWhitelist) . "\n";
                } else {
                    $rConf .= "ignoreip = 127.0.0.1/8 ::1\n";
                }
                $rConf .= "\n[sshd]\n";
                $rConf .= "enabled = true\n";
                $rConf .= "port = {$rPort}\n";
                $rConf .= "logpath = /var/log/auth.log\n";
                $rConf .= "maxretry = {$rMaxretry}\n";
                $rConf .= "bantime = {$rBantime}\n";

                file_put_contents('/tmp/jail_new.conf', $rConf);
                shell_exec("sudo cp /tmp/jail_new.conf /etc/fail2ban/jail.local && sudo fail2ban-client reload 2>&1");
                $_STATUS = 'success';
                $_MESSAGE = 'Configuracao salva e Fail2Ban recarregado';
                break;
        }
    }
}

// Get Fail2Ban status
$rF2BActive = trim(shell_exec("systemctl is-active fail2ban 2>/dev/null")) === 'active';
$rF2BStatus = shell_exec("sudo fail2ban-client status 2>/dev/null");

// Get all jails
$rJails = array();
if ($rF2BActive) {
    preg_match('/Jail list:\s*(.+)/', $rF2BStatus, $rMatches);
    if (!empty($rMatches[1])) {
        $rJails = array_map('trim', explode(',', $rMatches[1]));
    }
}

// Parse ban timestamps from fail2ban log
$rBanLog = shell_exec("sudo grep 'Ban\\|Unban' /var/log/fail2ban.log 2>/dev/null");
$rBanTimes = array();
if ($rBanLog) {
    foreach (explode("\n", trim($rBanLog)) as $rLine) {
        if (preg_match('/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}).*\[(\w+)\]\s+(Ban|Unban)\s+([\d\.]+)/', $rLine, $m)) {
            $rBanTimes[$m[4]] = array('time' => $m[1], 'action' => $m[3], 'jail' => $m[2]);
        }
    }
}

// Get banned IPs per jail
$rBannedData = array();
$rTotalBanned = 0;
$rTotalFailed = 0;
foreach ($rJails as $rJail) {
    $rJailStatus = shell_exec("sudo fail2ban-client status " . escapeshellarg($rJail) . " 2>/dev/null");
    preg_match('/Currently banned:\s*(\d+)/', $rJailStatus, $mBanned);
    preg_match('/Total banned:\s*(\d+)/', $rJailStatus, $mTotalBanned);
    preg_match('/Currently failed:\s*(\d+)/', $rJailStatus, $mFailed);
    preg_match('/Total failed:\s*(\d+)/', $rJailStatus, $mTotalFailed);
    preg_match('/Banned IP list:\s*(.*)/', $rJailStatus, $mIPs);

    $rBannedIPs = !empty($mIPs[1]) ? array_filter(array_map('trim', explode(' ', $mIPs[1]))) : array();

    $rBannedData[$rJail] = array(
        'currently_banned' => intval($mBanned[1] ?? 0),
        'total_banned' => intval($mTotalBanned[1] ?? 0),
        'currently_failed' => intval($mFailed[1] ?? 0),
        'total_failed' => intval($mTotalFailed[1] ?? 0),
        'banned_ips' => $rBannedIPs
    );
    $rTotalBanned += intval($mBanned[1] ?? 0);
    $rTotalFailed += intval($mTotalFailed[1] ?? 0);
}

// Get recent auth failures
$rRecentFailures = shell_exec("grep 'Failed password' /var/log/auth.log 2>/dev/null | tail -10");
$rFailuresByIP = shell_exec("grep 'Failed password' /var/log/auth.log 2>/dev/null | grep -oP '\\d+\\.\\d+\\.\\d+\\.\\d+' | sort | uniq -c | sort -rn | head -15");

// Read current jail.local config
$rJailConf = file_get_contents('/etc/fail2ban/jail.local');
$rConfBantime = 86400;
$rConfFindtime = 600;
$rConfMaxretry = 3;
$rConfPort = 2288;
$rConfWhitelist = '';
if ($rJailConf) {
    if (preg_match('/^\s*bantime\s*=\s*(\d+)/m', $rJailConf, $m)) $rConfBantime = intval($m[1]);
    if (preg_match('/^\s*findtime\s*=\s*(\d+)/m', $rJailConf, $m)) $rConfFindtime = intval($m[1]);
    if (preg_match('/^\s*maxretry\s*=\s*(\d+)/m', $rJailConf, $m)) $rConfMaxretry = intval($m[1]);
    if (preg_match('/^\s*port\s*=\s*(\d+)/m', $rJailConf, $m)) $rConfPort = intval($m[1]);
    if (preg_match('/^\s*ignoreip\s*=\s*(.+)/m', $rJailConf, $m)) {
        $rConfWhitelist = trim(str_replace(array('127.0.0.1/8', '::1'), '', $m[1]));
    }
}

// Bantime human readable
function bantimeHuman($s) {
    if ($s >= 86400) return intval($s/86400) . ' dia(s)';
    if ($s >= 3600) return intval($s/3600) . ' hora(s)';
    return intval($s/60) . ' minuto(s)';
}

include 'header.php';
?>

<div class="wrapper boxed-layout-ext">
    <div class="container-fluid">
        <div class="row">
            <div class="col-12">
                <div class="page-title-box">
                    <div class="page-title-right">
                        <?php include 'topbar.php'; ?>
                    </div>
                    <h4 class="page-title"><i class="mdi mdi-shield-lock"></i> Fail2Ban Firewall</h4>
                </div>
            </div>
        </div>

        <?php if (isset($_STATUS)): ?>
            <div class="alert alert-<?= $_STATUS ?> alert-dismissible fade show" role="alert">
                <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
                <?= $_MESSAGE ?>
            </div>
        <?php endif; ?>

        <!-- Status Cards -->
        <div class="row">
            <div class="col-xl-3 col-md-6">
                <div class="card widget-box-two <?= $rF2BActive ? 'border-success' : 'border-danger' ?>">
                    <div class="card-body">
                        <div class="media">
                            <div class="media-body wigdet-two-content">
                                <p class="m-0 text-uppercase font-weight-medium text-truncate" title="Status">Status</p>
                                <h3><span><?= $rF2BActive ? '<span class="text-success">ATIVO</span>' : '<span class="text-danger">PARADO</span>' ?></span></h3>
                            </div>
                            <div class="wigdet-two-icon">
                                <i class="mdi mdi-<?= $rF2BActive ? 'shield-check' : 'shield-off' ?>"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-xl-3 col-md-6">
                <div class="card widget-box-two border-warning">
                    <div class="card-body">
                        <div class="media">
                            <div class="media-body wigdet-two-content">
                                <p class="m-0 text-uppercase font-weight-medium text-truncate">IPs Banidos</p>
                                <h3><span><?= $rTotalBanned ?></span></h3>
                            </div>
                            <div class="wigdet-two-icon">
                                <i class="mdi mdi-block-helper"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-xl-3 col-md-6">
                <div class="card widget-box-two border-danger">
                    <div class="card-body">
                        <div class="media">
                            <div class="media-body wigdet-two-content">
                                <p class="m-0 text-uppercase font-weight-medium text-truncate">Tentativas Falhas</p>
                                <h3><span><?= $rTotalFailed ?></span></h3>
                            </div>
                            <div class="wigdet-two-icon">
                                <i class="mdi mdi-alert-circle"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-xl-3 col-md-6">
                <div class="card widget-box-two border-info">
                    <div class="card-body">
                        <div class="media">
                            <div class="media-body wigdet-two-content">
                                <p class="m-0 text-uppercase font-weight-medium text-truncate">Jails Ativos</p>
                                <h3><span><?= count($rJails) ?></span></h3>
                            </div>
                            <div class="wigdet-two-icon">
                                <i class="mdi mdi-security"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Controls -->
        <div class="row">
            <div class="col-12">
                <div class="card">
                    <div class="card-body">
                        <h5 class="card-title">Controles</h5>
                        <div class="btn-group">
                            <?php if ($rF2BActive): ?>
                                <form method="POST" style="display:inline">
                                    <input type="hidden" name="action" value="stop">
                                    <button class="btn btn-danger btn-sm mr-2" onclick="return confirm('Tem certeza? O servidor ficará desprotegido!')">
                                        <i class="mdi mdi-stop"></i> Parar Fail2Ban
                                    </button>
                                </form>
                                <form method="POST" style="display:inline">
                                    <input type="hidden" name="action" value="restart">
                                    <button class="btn btn-warning btn-sm mr-2">
                                        <i class="mdi mdi-refresh"></i> Reiniciar
                                    </button>
                                </form>
                                <form method="POST" style="display:inline">
                                    <input type="hidden" name="action" value="unban_all">
                                    <button class="btn btn-info btn-sm mr-2" onclick="return confirm('Desbloquear TODOS os IPs?')">
                                        <i class="mdi mdi-lock-open"></i> Desbloquear Todos
                                    </button>
                                </form>
                            <?php else: ?>
                                <form method="POST" style="display:inline">
                                    <input type="hidden" name="action" value="start">
                                    <button class="btn btn-success btn-sm">
                                        <i class="mdi mdi-play"></i> Iniciar Fail2Ban
                                    </button>
                                </form>
                            <?php endif; ?>
                        </div>

                        <!-- Manual Ban -->
                        <div class="mt-3">
                            <form method="POST" class="form-inline">
                                <input type="hidden" name="action" value="ban">
                                <input type="hidden" name="jail" value="sshd">
                                <div class="form-group mr-2">
                                    <input type="text" name="ip" class="form-control form-control-sm" placeholder="IP para banir (ex: 1.2.3.4)" pattern="[\d\.\:]+" required>
                                </div>
                                <button class="btn btn-dark btn-sm"><i class="mdi mdi-block-helper"></i> Banir IP</button>
                            </form>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Configuration -->
        <div class="row">
            <div class="col-12">
                <div class="card">
                    <div class="card-body">
                        <h5 class="card-title"><i class="mdi mdi-settings"></i> Configuracao do Fail2Ban</h5>
                        <p class="text-muted mb-3">Altere os parametros e clique em Salvar. O Fail2Ban sera recarregado automaticamente.</p>
                        <form method="POST">
                            <input type="hidden" name="action" value="save_config">
                            <div class="row">
                                <div class="col-md-3">
                                    <div class="form-group">
                                        <label>Tempo de Ban (segundos)</label>
                                        <input type="number" name="bantime" class="form-control" value="<?= $rConfBantime ?>" min="60">
                                        <small class="text-muted">Atual: <?= bantimeHuman($rConfBantime) ?></small>
                                    </div>
                                </div>
                                <div class="col-md-3">
                                    <div class="form-group">
                                        <label>Janela de Tempo (segundos)</label>
                                        <input type="number" name="findtime" class="form-control" value="<?= $rConfFindtime ?>" min="60">
                                        <small class="text-muted">Atual: <?= bantimeHuman($rConfFindtime) ?></small>
                                    </div>
                                </div>
                                <div class="col-md-3">
                                    <div class="form-group">
                                        <label>Max Tentativas</label>
                                        <input type="number" name="maxretry" class="form-control" value="<?= $rConfMaxretry ?>" min="1" max="100">
                                        <small class="text-muted">Ban apos <?= $rConfMaxretry ?> falha(s)</small>
                                    </div>
                                </div>
                                <div class="col-md-3">
                                    <div class="form-group">
                                        <label>Porta SSH</label>
                                        <input type="number" name="port" class="form-control" value="<?= $rConfPort ?>" min="1" max="65535">
                                        <small class="text-muted">Porta monitorada</small>
                                    </div>
                                </div>
                            </div>
                            <div class="row">
                                <div class="col-md-8">
                                    <div class="form-group">
                                        <label>IPs na Whitelist (nunca banir)</label>
                                        <input type="text" name="whitelist" class="form-control" value="<?= htmlspecialchars(trim($rConfWhitelist)) ?>" placeholder="Ex: 45.186.240.164 192.168.0.0/16">
                                        <small class="text-muted">Separe por espaco. Seu IP, IPs de confianca. 127.0.0.1 e ::1 ja incluidos.</small>
                                    </div>
                                </div>
                                <div class="col-md-4 d-flex align-items-end">
                                    <div class="form-group w-100">
                                        <button type="submit" class="btn btn-primary btn-block" onclick="return confirm('Salvar configuracao e recarregar Fail2Ban?')">
                                            <i class="mdi mdi-content-save"></i> Salvar Configuracao
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </form>

                        <hr>
                        <h6 class="text-muted">Resumo da configuracao atual</h6>
                        <div class="row">
                            <div class="col-md-3"><strong>Ban:</strong> <?= bantimeHuman($rConfBantime) ?></div>
                            <div class="col-md-3"><strong>Janela:</strong> <?= bantimeHuman($rConfFindtime) ?></div>
                            <div class="col-md-3"><strong>Tentativas:</strong> <?= $rConfMaxretry ?></div>
                            <div class="col-md-3"><strong>Porta SSH:</strong> <?= $rConfPort ?></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Banned IPs per Jail -->
        <?php foreach ($rBannedData as $rJail => $rData): ?>
            <div class="row">
                <div class="col-12">
                    <div class="card">
                        <div class="card-body">
                            <h5 class="card-title">
                                <i class="mdi mdi-jail"></i> Jail: <?= strtoupper(htmlspecialchars($rJail)) ?>
                                <span class="badge badge-warning ml-2"><?= $rData['currently_banned'] ?> banidos</span>
                                <span class="badge badge-danger ml-1"><?= $rData['total_failed'] ?> falhas</span>
                            </h5>
                            <?php if (!empty($rData['banned_ips'])): ?>
                                <div class="table-responsive">
                                    <table class="table table-striped table-centered mb-0">
                                        <thead>
                                            <tr>
                                                <th>#</th>
                                                <th>IP Banido</th>
                                                <th>Data / Hora do Ban</th>
                                                <th>Acoes</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <?php foreach ($rData['banned_ips'] as $i => $rIP): ?>
                                                <tr>
                                                    <td><?= $i + 1 ?></td>
                                                    <td>
                                                        <code><?= htmlspecialchars($rIP) ?></code>
                                                    </td>
                                                    <td>
                                                        <?php if (isset($rBanTimes[$rIP])): ?>
                                                            <span class="text-dark"><?= htmlspecialchars($rBanTimes[$rIP]['time']) ?></span>
                                                        <?php else: ?>
                                                            <span class="text-muted">-</span>
                                                        <?php endif; ?>
                                                    </td>
                                                    <td>
                                                        <form method="POST" style="display:inline">
                                                            <input type="hidden" name="action" value="unban">
                                                            <input type="hidden" name="jail" value="<?= htmlspecialchars($rJail) ?>">
                                                            <input type="hidden" name="ip" value="<?= htmlspecialchars($rIP) ?>">
                                                            <button class="btn btn-success btn-xs" title="Desbloquear">
                                                                <i class="mdi mdi-lock-open"></i> Liberar
                                                            </button>
                                                        </form>
                                                    </td>
                                                </tr>
                                            <?php endforeach; ?>
                                        </tbody>
                                    </table>
                                </div>
                            <?php else: ?>
                                <p class="text-muted">Nenhum IP banido neste jail.</p>
                            <?php endif; ?>
                        </div>
                    </div>
                </div>
            </div>
        <?php endforeach; ?>

        <!-- Top Attackers -->
        <div class="row">
            <div class="col-xl-6">
                <div class="card">
                    <div class="card-body">
                        <h5 class="card-title"><i class="mdi mdi-skull-crossbones"></i> Top Atacantes (SSH)</h5>
                        <?php if (!empty($rFailuresByIP)): ?>
                            <div class="table-responsive">
                                <table class="table table-sm table-striped mb-0">
                                    <thead>
                                        <tr><th>Tentativas</th><th>IP</th><th>Acoes</th></tr>
                                    </thead>
                                    <tbody>
                                        <?php foreach (explode("\n", trim($rFailuresByIP)) as $rLine):
                                            $rParts = preg_split('/\s+/', trim($rLine));
                                            if (count($rParts) >= 2):
                                                $rCount = $rParts[0];
                                                $rIP = $rParts[1];
                                        ?>
                                            <tr>
                                                <td><span class="badge badge-<?= $rCount > 100 ? 'danger' : ($rCount > 20 ? 'warning' : 'info') ?>"><?= $rCount ?></span></td>
                                                <td><code><?= htmlspecialchars($rIP) ?></code></td>
                                                <td>
                                                    <form method="POST" style="display:inline">
                                                        <input type="hidden" name="action" value="ban">
                                                        <input type="hidden" name="jail" value="sshd">
                                                        <input type="hidden" name="ip" value="<?= htmlspecialchars($rIP) ?>">
                                                        <button class="btn btn-danger btn-xs" title="Banir">
                                                            <i class="mdi mdi-block-helper"></i>
                                                        </button>
                                                    </form>
                                                </td>
                                            </tr>
                                        <?php endif; endforeach; ?>
                                    </tbody>
                                </table>
                            </div>
                        <?php else: ?>
                            <p class="text-muted">Nenhuma tentativa registrada.</p>
                        <?php endif; ?>
                    </div>
                </div>
            </div>

            <!-- Recent Failures Log -->
            <div class="col-xl-6">
                <div class="card">
                    <div class="card-body">
                        <h5 class="card-title"><i class="mdi mdi-file-document"></i> Ultimas Tentativas Falhas</h5>
                        <pre style="max-height:400px; overflow-y:auto; font-size:11px; background:#2c3e50; color:#ecf0f1; padding:15px; border-radius:5px;"><?php
                            if (!empty($rRecentFailures)) {
                                echo htmlspecialchars($rRecentFailures);
                            } else {
                                echo "Nenhuma tentativa falha recente.";
                            }
                        ?></pre>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<script>
    <?php if (CoreUtilities::$rSettings['enable_search']): ?>
        $(document).ready(function() { initSearch(); });
    <?php endif; ?>
</script>
</body>
</html>
