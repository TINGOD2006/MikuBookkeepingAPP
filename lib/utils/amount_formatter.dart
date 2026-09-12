import 'dart:math' as math;

/// 金額格式化工具。
///
/// 專案中的記錄金額一律以 `double`（浮點數）儲存，本工具負責把浮點數轉成
/// 適合顯示的字串，規則與 Android 原生端的 `formatAmount()` 一致：
///   * 最多保留 [decimalPlaces] 位小數（四捨五入）
///   * 整數金額不顯示小數（12.00 → "12"）
///   * 有小數時移除尾端多餘的 0（12.50 → "12.5"）
class AmountFormatter {
  const AmountFormatter._();

  /// 金額的最大小數位數（與原生端 `%.2f` 一致）。
  static const int decimalPlaces = 2;

  static final double _scale = math.pow(10, decimalPlaces).toDouble();

  /// 把金額四捨五入到 [decimalPlaces] 位小數。
  ///
  /// 浮點運算（例如 0.1 + 0.2）會產生 0.30000000000000004 這類誤差，
  /// 在存檔前先正規化，可避免誤差隨著加總不斷累積。
  static double round(double value) {
    if (!value.isFinite) return 0;
    return (value * _scale).roundToDouble() / _scale;
  }

  /// 格式化金額（不含千分位），例如 `1234.5`、`12`、`-0.75`。
  static String format(double value) {
    if (!value.isFinite) return '0';

    var text = round(value).toStringAsFixed(decimalPlaces);
    if (text.contains('.')) {
      // 移除尾端多餘的 0，以及只剩下小數點的情況
      text = text.replaceFirst(RegExp(r'0+$'), '');
      if (text.endsWith('.')) {
        text = text.substring(0, text.length - 1);
      }
    }
    // 避免出現 "-0"
    return (text.isEmpty || text == '-0') ? '0' : text;
  }

  /// 格式化金額並加上千分位，例如 `1,234.5`。
  static String formatWithSeparator(double value) {
    final text = format(value);
    final isNegative = text.startsWith('-');
    final body = isNegative ? text.substring(1) : text;
    final dotIndex = body.indexOf('.');
    final integerPart = dotIndex < 0 ? body : body.substring(0, dotIndex);
    final decimalPart = dotIndex < 0 ? '' : body.substring(dotIndex);

    final grouped = integerPart.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]},',
    );
    return '${isNegative ? '-' : ''}$grouped$decimalPart';
  }

  /// 為「輸入中」的金額字串加上千分位。
  ///
  /// 與 [formatWithSeparator] 不同，這裡處理的是使用者正在輸入的內容，
  /// 可能長成 `1234.` 這種結尾帶小數點、還無法 parse 成 double 的字串，
  /// 因此只對整數部分分組，小數部分原樣保留。
  static String formatInput(String input) {
    if (input.isEmpty) return '0';

    final dotIndex = input.indexOf('.');
    final integerPart = dotIndex < 0 ? input : input.substring(0, dotIndex);
    final decimalPart = dotIndex < 0 ? '' : input.substring(dotIndex);

    final grouped = integerPart.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]},',
    );
    return '$grouped$decimalPart';
  }
}
