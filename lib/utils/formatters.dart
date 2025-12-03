import 'package:intl/intl.dart';

class Formatters {
  static String formatCurrency(double amount, String currency) {
    // Sederhana saja untuk konversi tampilan
    final format = NumberFormat.currency(
      locale: 'id_ID', 
      symbol: currency == 'IDR' ? 'Rp ' : (currency == 'USD' ? '\$ ' : '€ '),
      decimalDigits: 2
    );
    return format.format(amount);
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }
}