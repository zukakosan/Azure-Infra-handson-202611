using './main.bicep'
// ここに、自分用の任意の文字列を入れる
param exerciseId = '<自分用の ID を記載>'

// クォータ不足時は、sourceLocation / recoveryLocation をペアで変更する。
// 候補（元 / 復旧先。逆方向も可）:
//   東日本 / 西日本             : japaneast / japanwest（既定）
//   東南アジア / 東アジア       : southeastasia / eastasia
//   オーストラリア東部 / 南東部 : australiaeast / australiasoutheast
//   北ヨーロッパ / 西ヨーロッパ : northeurope / westeurope
//   米国東部2 / 米国中部        : eastus2 / centralus
// 公式ペア: https://learn.microsoft.com/azure/reliability/regions-paired
// 両側の Bastion Developer 対応を確認した候補。実行前にサービス対応、
// VMサイズ・イメージ・両側のvCPUクォータ・容量・許可リージョンを再確認する。
// 作成済みリソースの移動には使わない。途中で変更する場合は既存環境を片付け、
// 新しい exerciseId で作り直す。以降のPortal手順も選択したリージョンに読み替える。
param sourceLocation = 'japaneast'
param recoveryLocation = 'japanwest'

// VM 用の管理者パスワードは、環境変数から読み込み 
param adminPassword = readEnvironmentVariable('BCDR_ADMIN_PASSWORD')
