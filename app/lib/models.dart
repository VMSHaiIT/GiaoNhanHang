// Auth Models
class LoginRequest {
  final String email;
  final String userLogin;
  final String passwordLogin;

  LoginRequest({
    required this.email,
    required this.userLogin,
    required this.passwordLogin,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'userLogin': userLogin,
        'passwordLogin': passwordLogin,
      };
}

class CheckEmailRequest {
  final String email;

  CheckEmailRequest({required this.email});

  Map<String, dynamic> toJson() => {
        'email': email,
      };
}

class CheckEmailResponse {
  final bool exists;
  final String message;

  CheckEmailResponse({
    required this.exists,
    required this.message,
  });

  factory CheckEmailResponse.fromJson(Map<String, dynamic> json) =>
      CheckEmailResponse(
        exists: json['exists'] as bool,
        message: json['message'] as String,
      );
}

class LoginResponse {
  final bool success;
  final String message;
  final String? databaseName;
  final String? token;
  final String? refreshToken;
  final String? userRole;

  LoginResponse({
    required this.success,
    required this.message,
    this.databaseName,
    this.token,
    this.refreshToken,
    this.userRole,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        success: json['success'] as bool,
        message: json['message'] as String,
        databaseName: json['databaseName'] as String?,
        token: json['token'] as String?,
        refreshToken: json['refreshToken'] as String?,
        userRole: json['userRole'] as String?,
      );
}

// Business Models
class Order {
  final String orderID;
  final DateTime orderDate;
  final DateTime expectedDeliveryDate;
  final String orderType;
  final double totalValue;
  final String? note;
  final double totalWeight;
  final double totalAmount;
  final String status;
  final DateTime createdDate;
  final String createdBy;
  final String? senderID;
  final String? receiverID;
  final String? routeID;
  final String? tripID;
  final Sender? sender;
  final Receiver? receiver;
  final Route? route;
  final Trip? trip;
  final List<OrderItem>? orderItems;
  final Payment? payment;

  Order({
    required this.orderID,
    required this.orderDate,
    required this.expectedDeliveryDate,
    required this.orderType,
    required this.totalValue,
    this.note,
    required this.totalWeight,
    required this.totalAmount,
    required this.status,
    required this.createdDate,
    required this.createdBy,
    this.senderID,
    this.receiverID,
    this.routeID,
    this.tripID,
    this.sender,
    this.receiver,
    this.route,
    this.trip,
    this.orderItems,
    this.payment,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        orderID: json['orderID'] as String,
        orderDate: DateTime.parse(json['orderDate'] as String),
        expectedDeliveryDate:
            DateTime.parse(json['expectedDeliveryDate'] as String),
        orderType: json['orderType'] as String,
        totalValue: (json['totalValue'] as num).toDouble(),
        note: json['note'] as String?,
        totalWeight: (json['totalWeight'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        status: json['status'] as String,
        createdDate: DateTime.parse(json['createdDate'] as String),
        createdBy: json['createdBy'] as String,
        senderID: json['senderID'] as String?,
        receiverID: json['receiverID'] as String?,
        routeID: json['routeID'] as String?,
        tripID: json['tripID'] as String?,
        sender: json['sender'] != null ? Sender.fromJson(json['sender']) : null,
        receiver: json['receiver'] != null
            ? Receiver.fromJson(json['receiver'])
            : null,
        route: json['route'] != null ? Route.fromJson(json['route']) : null,
        trip: json['trip'] != null ? Trip.fromJson(json['trip']) : null,
        orderItems: json['orderItems'] != null
            ? (json['orderItems'] as List)
                .map((e) => OrderItem.fromJson(e))
                .toList()
            : null,
        payment:
            json['payment'] != null ? Payment.fromJson(json['payment']) : null,
      );

  Map<String, dynamic> toJson() => {
        'orderID': orderID,
        'orderDate': orderDate.toIso8601String(),
        'expectedDeliveryDate': expectedDeliveryDate.toIso8601String(),
        'orderType': orderType,
        'totalValue': totalValue,
        'note': note,
        'totalWeight': totalWeight,
        'totalAmount': totalAmount,
        'status': status,
        'createdDate': createdDate.toIso8601String(),
        'createdBy': createdBy,
        'senderID': senderID,
        'receiverID': receiverID,
        'routeID': routeID,
        'tripID': tripID,
      };
}

class Sender {
  final String senderID;
  final String phone;
  final String name;
  final String? address;
  final String? branchID;
  final String? district;
  final bool pickupRequired;
  final String? pickupStaffID;
  final Branch? branch;
  final Staff? pickupStaff;

  Sender({
    required this.senderID,
    required this.phone,
    required this.name,
    this.address,
    this.branchID,
    this.district,
    this.pickupRequired = false,
    this.pickupStaffID,
    this.branch,
    this.pickupStaff,
  });

  factory Sender.fromJson(Map<String, dynamic> json) => Sender(
        senderID: json['senderID'] as String,
        phone: json['phone'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
        branchID: json['branchID'] as String?,
        district: json['district'] as String?,
        pickupRequired: json['pickupRequired'] as bool? ?? false,
        pickupStaffID: json['pickupStaffID'] as String?,
        branch: json['branch'] != null ? Branch.fromJson(json['branch']) : null,
        pickupStaff: json['pickupStaff'] != null
            ? Staff.fromJson(json['pickupStaff'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'senderID': senderID,
        'phone': phone,
        'name': name,
        'address': address,
        'branchID': branchID,
        'district': district,
        'pickupRequired': pickupRequired,
        'pickupStaffID': pickupStaffID,
      };
}

class Receiver {
  final String receiverID;
  final String phone;
  final String name;
  final String? address;
  final String? branchID;
  final String? district;
  final bool deliveryRequired;
  final String? deliveryStaffID;
  final Branch? branch;
  final Staff? deliveryStaff;

  Receiver({
    required this.receiverID,
    required this.phone,
    required this.name,
    this.address,
    this.branchID,
    this.district,
    this.deliveryRequired = false,
    this.deliveryStaffID,
    this.branch,
    this.deliveryStaff,
  });

  factory Receiver.fromJson(Map<String, dynamic> json) => Receiver(
        receiverID: json['receiverID'] as String,
        phone: json['phone'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
        branchID: json['branchID'] as String?,
        district: json['district'] as String?,
        deliveryRequired: json['deliveryRequired'] as bool? ?? false,
        deliveryStaffID: json['deliveryStaffID'] as String?,
        branch: json['branch'] != null ? Branch.fromJson(json['branch']) : null,
        deliveryStaff: json['deliveryStaff'] != null
            ? Staff.fromJson(json['deliveryStaff'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'receiverID': receiverID,
        'phone': phone,
        'name': name,
        'address': address,
        'branchID': branchID,
        'district': district,
        'deliveryRequired': deliveryRequired,
        'deliveryStaffID': deliveryStaffID,
      };
}

class OrderItem {
  final String itemID;
  final String orderID;
  final String itemName;
  final String unit;
  final double weight;
  final int quantity;
  final double price;
  final double amount;

  OrderItem({
    required this.itemID,
    required this.orderID,
    required this.itemName,
    required this.unit,
    required this.weight,
    required this.quantity,
    required this.price,
    required this.amount,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        itemID: json['itemID'] as String,
        orderID: json['orderID'] as String,
        itemName: json['itemName'] as String,
        unit: json['unit'] as String,
        weight: (json['weight'] as num).toDouble(),
        quantity: json['quantity'] as int,
        price: (json['price'] as num).toDouble(),
        amount: (json['amount'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'itemID': itemID,
        'orderID': orderID,
        'itemName': itemName,
        'unit': unit,
        'weight': weight,
        'quantity': quantity,
        'price': price,
        'amount': amount,
      };
}

class Payment {
  final String paymentID;
  final String orderID;
  final double shippingFee;
  final double codAmount;
  final double codFee;
  final double totalPayment;
  final String paymentMethod;

  Payment({
    required this.paymentID,
    required this.orderID,
    required this.shippingFee,
    required this.codAmount,
    required this.codFee,
    required this.totalPayment,
    required this.paymentMethod,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        paymentID: json['paymentID'] as String,
        orderID: json['orderID'] as String,
        shippingFee: (json['shippingFee'] as num).toDouble(),
        codAmount: (json['codAmount'] as num).toDouble(),
        codFee: (json['codFee'] as num).toDouble(),
        totalPayment: (json['totalPayment'] as num).toDouble(),
        paymentMethod: json['paymentMethod'] as String,
      );

  Map<String, dynamic> toJson() => {
        'paymentID': paymentID,
        'orderID': orderID,
        'shippingFee': shippingFee,
        'codAmount': codAmount,
        'codFee': codFee,
        'totalPayment': totalPayment,
        'paymentMethod': paymentMethod,
      };
}

class Route {
  final String routeID;
  final String routeName;
  final String origin;
  final String destination;
  final String transportType;

  Route({
    required this.routeID,
    required this.routeName,
    required this.origin,
    required this.destination,
    required this.transportType,
  });

  factory Route.fromJson(Map<String, dynamic> json) => Route(
        routeID: json['routeID'] as String,
        routeName: json['routeName'] as String,
        origin: json['origin'] as String,
        destination: json['destination'] as String,
        transportType: json['transportType'] as String,
      );

  Map<String, dynamic> toJson() => {
        'routeID': routeID,
        'routeName': routeName,
        'origin': origin,
        'destination': destination,
        'transportType': transportType,
      };
}

class Trip {
  final String tripID;
  final String routeID;
  final String? vehicleID;
  final String? driverID;
  final DateTime? departureTime;
  final DateTime? arrivalTime;
  final String status;
  final Route? route;
  final Vehicle? vehicle;
  final Staff? driver;

  Trip({
    required this.tripID,
    required this.routeID,
    this.vehicleID,
    this.driverID,
    this.departureTime,
    this.arrivalTime,
    required this.status,
    this.route,
    this.vehicle,
    this.driver,
  });

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        tripID: json['tripID'] as String,
        routeID: json['routeID'] as String,
        vehicleID: json['vehicleID'] as String?,
        driverID: json['driverID'] as String?,
        departureTime: json['departureTime'] != null
            ? DateTime.parse(json['departureTime'])
            : null,
        arrivalTime: json['arrivalTime'] != null
            ? DateTime.parse(json['arrivalTime'])
            : null,
        status: json['status'] as String,
        route: json['route'] != null ? Route.fromJson(json['route']) : null,
        vehicle:
            json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
        driver: json['driver'] != null ? Staff.fromJson(json['driver']) : null,
      );

  Map<String, dynamic> toJson() => {
        'tripID': tripID,
        'routeID': routeID,
        'vehicleID': vehicleID,
        'driverID': driverID,
        'departureTime': departureTime?.toIso8601String(),
        'arrivalTime': arrivalTime?.toIso8601String(),
        'status': status,
      };
}

class Branch {
  final String branchID;
  final String branchName;

  Branch({
    required this.branchID,
    required this.branchName,
  });

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
        branchID: json['branchID'] as String,
        branchName: json['branchName'] as String,
      );

  Map<String, dynamic> toJson() => {
        'branchID': branchID,
        'branchName': branchName,
      };
}

class Vehicle {
  final String vehicleID;
  final String vehicleName;

  Vehicle({
    required this.vehicleID,
    required this.vehicleName,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        vehicleID: json['vehicleID'] as String,
        vehicleName: json['vehicleName'] as String,
      );

  Map<String, dynamic> toJson() => {
        'vehicleID': vehicleID,
        'vehicleName': vehicleName,
      };
}

class Staff {
  final String staffID;
  final String name;
  final String phone;

  Staff({
    required this.staffID,
    required this.name,
    required this.phone,
  });

  factory Staff.fromJson(Map<String, dynamic> json) => Staff(
        staffID: json['staffID'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
      );

  Map<String, dynamic> toJson() => {
        'staffID': staffID,
        'name': name,
        'phone': phone,
      };
}

// Request Models
class CreateOrderRequest {
  final Order order;
  final Sender? sender;
  final Receiver? receiver;
  final List<OrderItem>? orderItems;
  final Payment? payment;

  CreateOrderRequest({
    required this.order,
    this.sender,
    this.receiver,
    this.orderItems,
    this.payment,
  });

  Map<String, dynamic> toJson() {
    final orderJson = order.toJson();
    return {
      'order': orderJson,
      'sender': sender?.toJson(),
      'receiver': receiver?.toJson(),
      'orderItems': orderItems
          ?.map((e) => {...e.toJson(), 'order': orderJson})
          .toList(),
      'payment': payment != null
          ? {...payment!.toJson(), 'order': orderJson}
          : null,
    };
  }
}
