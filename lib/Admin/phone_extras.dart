/// Presets displayed in the admin phone form.
const List<String> kQualityCheckPresets = <String>[
  'Display', 'Camera', 'Battery', 'Speakers & mic', 'Network & Wi-Fi',
  'Sensors', 'Charging port', 'Buttons', 'Touch screen',
  'Face / fingerprint unlock', 'Bluetooth', 'Water damage check',
];

const List<String> kInBoxPresets = <String>[
  'Phone', 'Original charger', 'Cable', 'Fresh box', 'Warranty card',
  'Earphones', 'Back cover', 'Screen guard',
];

const List<String> kPhotoLabels = <String>[
  'Front view', 'Back view', 'In the box', 'Other',
];

String defaultPhotoLabel(int index) =>
    index >= 0 && index < 3 ? kPhotoLabels[index] : 'Other';

int _intValue(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

/// One additional storage/condition combination with its own price and stock.
class PhoneVariant {
  String storage;
  String condition;
  int price;
  int mrp;
  int stock;

  PhoneVariant({
    required this.storage,
    required this.condition,
    required this.price,
    required this.mrp,
    required this.stock,
  });

  int get off => mrp > price && mrp > 0
      ? (((mrp - price) / mrp) * 100).round()
      : 0;

  PhoneVariant copy() => PhoneVariant(
    storage: storage,
    condition: condition,
    price: price,
    mrp: mrp,
    stock: stock,
  );

  Map<String, dynamic> toMap() => {
    'storage': storage,
    'condition': condition,
    'price': price,
    'mrp': mrp,
    'stock': stock,
  };

  factory PhoneVariant.fromMap(Map<String, dynamic> map) => PhoneVariant(
    storage: '${map['storage'] ?? ''}',
    condition: '${map['condition'] ?? ''}',
    price: _intValue(map['price']),
    mrp: _intValue(map['mrp']),
    stock: _intValue(map['stock']),
  );
}

/// Optional customer-facing product specifications and purchase policies.
class PhoneDetails {
  String display;
  String processor;
  String ram;
  String rearCamera;
  String frontCamera;
  String batteryMah;
  String os;

  List<String> qualityChecks;
  List<String> inBox;
  List<String> imageLabels;
  List<PhoneVariant> variants;

  int warrantyMonths;
  int returnDays;
  int deliveryDays;
  bool cod;
  bool noCostEmi;

  PhoneDetails({
    this.display = '',
    this.processor = '',
    this.ram = '',
    this.rearCamera = '',
    this.frontCamera = '',
    this.batteryMah = '',
    this.os = '',
    List<String>? qualityChecks,
    List<String>? inBox,
    List<String>? imageLabels,
    List<PhoneVariant>? variants,
    this.warrantyMonths = 6,
    this.returnDays = 7,
    this.deliveryDays = 3,
    this.cod = true,
    this.noCostEmi = true,
  })  : qualityChecks = qualityChecks ?? <String>[],
        inBox = inBox ?? <String>[],
        imageLabels = imageLabels ?? <String>[],
        variants = variants ?? <PhoneVariant>[];

  List<(String, String)> get specRows => [
    ('Display', display),
    ('Processor', processor),
    ('RAM', ram),
    ('Rear camera', rearCamera),
    ('Front camera', frontCamera),
    ('Battery', batteryMah),
    ('Operating system', os),
  ].where((row) => row.$2.trim().isNotEmpty).toList();

  PhoneDetails copy() => PhoneDetails(
    display: display,
    processor: processor,
    ram: ram,
    rearCamera: rearCamera,
    frontCamera: frontCamera,
    batteryMah: batteryMah,
    os: os,
    qualityChecks: List<String>.from(qualityChecks),
    inBox: List<String>.from(inBox),
    imageLabels: List<String>.from(imageLabels),
    variants: variants.map((variant) => variant.copy()).toList(),
    warrantyMonths: warrantyMonths,
    returnDays: returnDays,
    deliveryDays: deliveryDays,
    cod: cod,
    noCostEmi: noCostEmi,
  );

  Map<String, dynamic> toMap() => {
    'display': display,
    'processor': processor,
    'ram': ram,
    'rearCamera': rearCamera,
    'frontCamera': frontCamera,
    'batteryMah': batteryMah,
    'os': os,
    'qualityChecks': qualityChecks,
    'inBox': inBox,
    'imageLabels': imageLabels,
    'variants': variants.map((variant) => variant.toMap()).toList(),
    'warrantyMonths': warrantyMonths,
    'returnDays': returnDays,
    'deliveryDays': deliveryDays,
    'cod': cod,
    'noCostEmi': noCostEmi,
  };

  factory PhoneDetails.fromMap(Map<String, dynamic>? map) {
    if (map == null) return PhoneDetails();

    List<String> strings(dynamic value) => value is List
        ? value.map((item) => '$item').toList()
        : <String>[];

    final rawVariants = map['variants'];
    final variants = rawVariants is List
        ? rawVariants
        .whereType<Map>()
        .map((item) => PhoneVariant.fromMap(
      Map<String, dynamic>.from(item),
    ))
        .toList()
        : <PhoneVariant>[];

    return PhoneDetails(
      display: '${map['display'] ?? ''}',
      processor: '${map['processor'] ?? ''}',
      ram: '${map['ram'] ?? ''}',
      rearCamera: '${map['rearCamera'] ?? ''}',
      frontCamera: '${map['frontCamera'] ?? ''}',
      batteryMah: '${map['batteryMah'] ?? ''}',
      os: '${map['os'] ?? ''}',
      qualityChecks: strings(map['qualityChecks']),
      inBox: strings(map['inBox']),
      imageLabels: strings(map['imageLabels']),
      variants: variants,
      warrantyMonths: _intValue(map['warrantyMonths'], 6),
      returnDays: _intValue(map['returnDays'], 7),
      deliveryDays: _intValue(map['deliveryDays'], 3),
      cod: map['cod'] is bool ? map['cod'] as bool : true,
      noCostEmi: map['noCostEmi'] is bool ? map['noCostEmi'] as bool : true,
    );
  }
}
