class OrderStatusLabels {
  static const String allStatus = 'all';
  static const String allLabel = 'Tất cả';

  // Thứ tự phản ánh luồng xử lý thực tế của đơn hàng
  static const Map<String, String> labels = {
    'pending': 'Chờ lấy',
    'collecting': 'Đang lấy',
    'in_stock': 'Trong kho',
    'delivering': 'Đang giao',
    'delivered': 'Đã giao',
    'cancelled': 'Đã hủy',
    'returned': 'Hoàn hàng',
  };

  static String labelFor(String status) {
    if (status == allStatus) return allLabel;
    return labels[status] ?? status;
  }
}
