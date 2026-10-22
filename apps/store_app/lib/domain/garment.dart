import 'garment_render_metadata.dart';

const garmentCategories = {
  'top': 'بالاتنه',
  'coat': 'کت و مانتو',
  'dress': 'پیراهن',
  'trousers': 'شلوار',
  'skirt': 'دامن',
};
const photoAngles = {
  'front': 'روبرو',
  'back': 'پشت',
  'left45': 'زاویه چپ',
  'right45': 'زاویه راست',
};

class Garment {
  Garment({
    required this.id,
    required this.name,
    this.localRevision = 0,
    this.category = 'top',
    this.collection = '',
    this.sku = '',
    this.barcode = '',
    this.price = 0,
    this.discountPrice,
    this.stock = 0,
    this.isActive = true,
    this.isDraft = true,
    this.archived = false,
    Map<String, Object?> metadata = const {},
    Map<String, String> photos = const {},
    Map<String, double> measurements = const {},
    Set<String> excludedFields = const {},
    this.processingStatus = 'notRequested',
    this.tryOnJson = '',
    required this.createdAt,
    required this.updatedAt,
  }) : metadata = Map.unmodifiable(metadata),
       photos = Map.unmodifiable(photos),
       measurements = Map.unmodifiable(measurements),
       excludedFields = Set.unmodifiable(excludedFields);

  factory Garment.create({required String id, required String name}) {
    final now = DateTime.now().toUtc();
    return Garment(id: id, name: name, createdAt: now, updatedAt: now);
  }

  final String id, name, category, collection, sku, barcode, processingStatus;
  final String tryOnJson;
  final int localRevision, price, stock;
  final int? discountPrice;
  final bool isActive, isDraft, archived;
  final Map<String, Object?> metadata;
  final Map<String, String> photos;
  final Map<String, double> measurements;
  final Set<String> excludedFields;
  final DateTime createdAt, updatedAt;

  // A local catalog photo is never a validated rendering asset.
  bool get tryOnEligible => false;
  int get effectivePrice => discountPrice ?? price;

  String? get renderMetadataError {
    try {
      GarmentRenderMetadata.parse(tryOnJson);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  List<String> validate() => [
    if (renderMetadataError case final String error) error,
    if (name.trim().isEmpty) 'نام لباس را وارد کنید',
    if (name.length > 120) 'نام لباس حداکثر ۱۲۰ نویسه است',
    if (!garmentCategories.containsKey(category)) 'دسته لباس نامعتبر است',
    if (price < 0) 'قیمت نمی‌تواند منفی باشد',
    if (price > 999999999999) 'قیمت از سقف مجاز بیشتر است',
    if (discountPrice != null &&
        (discountPrice! < 0 || discountPrice! >= price))
      'قیمت تخفیف باید نامنفی و کمتر از قیمت اصلی باشد',
    if (stock < 0) 'موجودی نمی‌تواند منفی باشد',
    if (stock > 999999) 'موجودی از سقف مجاز بیشتر است',
    if (measurements.values.any((v) => !v.isFinite || v <= 0 || v > 10000))
      'اندازه باید بین صفر و ۱۰۰۰۰ میلی‌متر باشد',
    if (!isDraft &&
        tryOnJson.trim().isNotEmpty &&
        photos['front_source'] == null)
      'برای پرو با JSON، عکس اصلی روبرو را دوباره انتخاب کنید',
    if (!isDraft && photos['front'] == null)
      'برای ثبت در کاتالوگ عکس روبرو لازم است',
  ];

  Garment copyWith({
    String? name,
    String? category,
    String? collection,
    String? sku,
    String? barcode,
    int? localRevision,
    int? price,
    int? discountPrice,
    bool clearDiscount = false,
    int? stock,
    bool? isActive,
    bool? isDraft,
    bool? archived,
    Map<String, Object?>? metadata,
    Map<String, String>? photos,
    Map<String, double>? measurements,
    Set<String>? excludedFields,
    String? processingStatus,
    String? tryOnJson,
    DateTime? updatedAt,
  }) => Garment(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    collection: collection ?? this.collection,
    sku: sku ?? this.sku,
    barcode: barcode ?? this.barcode,
    localRevision: localRevision ?? this.localRevision,
    price: price ?? this.price,
    discountPrice: clearDiscount ? null : discountPrice ?? this.discountPrice,
    stock: stock ?? this.stock,
    isActive: isActive ?? this.isActive,
    isDraft: isDraft ?? this.isDraft,
    archived: archived ?? this.archived,
    metadata: metadata ?? this.metadata,
    photos: photos ?? this.photos,
    measurements: measurements ?? this.measurements,
    excludedFields: excludedFields ?? this.excludedFields,
    processingStatus: processingStatus ?? this.processingStatus,
    tryOnJson: tryOnJson ?? this.tryOnJson,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'collection': collection,
    'sku': sku,
    'barcode': barcode,
    'localRevision': localRevision,
    'price': price,
    'discountPrice': discountPrice,
    'stock': stock,
    'isActive': isActive,
    'isDraft': isDraft,
    'archived': archived,
    'metadata': metadata,
    'photos': photos,
    'measurements': measurements,
    'excludedFields': excludedFields.toList(),
    'processingStatus': processingStatus,
    'tryOnJson': tryOnJson,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  factory Garment.fromJson(Map<String, dynamic> j) => Garment(
    id: j['id'] as String,
    name: j['name'] as String,
    category: j['category'] as String,
    collection: j['collection'] as String,
    sku: j['sku'] as String,
    barcode: j['barcode'] as String,
    localRevision: j['localRevision'] as int,
    price: j['price'] as int,
    discountPrice: j['discountPrice'] as int?,
    stock: j['stock'] as int,
    isActive: j['isActive'] as bool,
    isDraft: j['isDraft'] as bool,
    archived: j['archived'] as bool,
    metadata: Map<String, Object?>.from(j['metadata'] as Map),
    photos: Map<String, String>.from(j['photos'] as Map),
    measurements: (j['measurements'] as Map).map(
      (k, v) => MapEntry(k as String, (v as num).toDouble()),
    ),
    excludedFields: Set<String>.from(j['excludedFields'] as List),
    processingStatus: j['processingStatus'] as String,
    tryOnJson: j['tryOnJson'] as String? ?? '',
    createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
  );
}
