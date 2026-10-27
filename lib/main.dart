import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDb.instance.init();
  runApp(const RequestsApp());
}

class RequestsApp extends StatelessWidget {
  const RequestsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'طلبات',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff1769aa)), useMaterial3: true, scaffoldBackgroundColor: const Color(0xfff5f7fa)),
    home: const HomePage(),
  );
}

class AppDb {
  AppDb._();
  static final instance = AppDb._();
  Database? _db;
  Future<void> init() async {
    final root = await getDatabasesPath();
    _db = await openDatabase(p.join(root, 'requests.db'), version: 1, onCreate: (db, _) async {
      await db.execute('CREATE TABLE items(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, category TEXT NOT NULL, unit TEXT NOT NULL DEFAULT "حبة")');
      await db.execute('CREATE TABLE requests(id INTEGER PRIMARY KEY AUTOINCREMENT, itemId INTEGER, itemName TEXT NOT NULL, qty REAL NOT NULL, note TEXT, worker TEXT, status TEXT NOT NULL DEFAULT "جديد", createdAt TEXT NOT NULL, synced INTEGER NOT NULL DEFAULT 0)');
    });
  }
  Database get db => _db!;
  Future<List<Map<String,Object?>>> items() => db.query('items', orderBy: 'category,name');
  Future<List<Map<String,Object?>>> requests() => db.query('requests', orderBy: 'id DESC');
  Future<int> addItem(String name, String category, String unit) => db.insert('items', {'name':name,'category':category,'unit':unit});
  Future<int> addRequest(int? itemId, String name, double qty, String note, String worker) => db.insert('requests', {'itemId':itemId,'itemName':name,'qty':qty,'note':note,'worker':worker,'status':'جديد','createdAt':DateTime.now().toIso8601String(),'synced':0});
  Future<void> setStatus(int id, String status) => db.update('requests', {'status':status}, where:'id=?', whereArgs:[id]);
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  int tab=0;
  String shopName='إدارة الطلبات', address='', phone1='', phone2='', worker='عامل', logoPath='';
  List<Map<String,Object?>> items=[], requests=[];
  @override void initState(){super.initState(); _load();}
  Future<void> _load() async {
    final prefs=await SharedPreferences.getInstance();
    final i=await AppDb.instance.items(); final r=await AppDb.instance.requests();
    if(!mounted)return;
    setState(() { items=i; requests=r; shopName=prefs.getString('shopName')??'إدارة الطلبات'; address=prefs.getString('address')??''; phone1=prefs.getString('phone1')??''; phone2=prefs.getString('phone2')??''; worker=prefs.getString('worker')??'عامل'; logoPath=prefs.getString('logoPath')??''; });
  }
  Future<void> _addItem() async {
    final name=TextEditingController(), category=TextEditingController(), unit=TextEditingController(text:'حبة');
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('إضافة صنف جديد'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'اسم الصنف')),TextField(controller:category,decoration:const InputDecoration(labelText:'تصنيف الصنف (عند إنشاء الصنف)')),TextField(controller:unit,decoration:const InputDecoration(labelText:'وحدة القياس'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حفظ'))]));
    if(ok==true && name.text.trim().isNotEmpty && category.text.trim().isNotEmpty){await AppDb.instance.addItem(name.text.trim(),category.text.trim(),unit.text.trim().isEmpty?'حبة':unit.text.trim());await _load();}
  }
  Future<void> _addRequest() async {
    if(items.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('أضف الأصناف أولاً من قسم الأصناف')));return;}
    int? selected=items.first['id'] as int; final qty=TextEditingController(text:'1'), note=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تسجيل صنف ناقص'),content:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<int>(value:selected,decoration:const InputDecoration(labelText:'الصنف'),items:items.map((e)=>DropdownMenuItem(value:e['id'] as int,child:Text('${e['name']}'))).toList(),onChanged:(v)=>selected=v),TextField(controller:qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'الكمية المطلوبة')),TextField(controller:note,decoration:const InputDecoration(labelText:'ملاحظات / مواصفات'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('إرسال للمراجعة'))]));
    if(ok==true){final item=items.firstWhere((e)=>e['id']==selected);final q=double.tryParse(qty.text)??0;if(q>0){await AppDb.instance.addRequest(selected,item['name'].toString(),q,note.text,worker);await _load();}}
  }
  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('logoPath', picked.path);
    await _load();
  }
  Future<void> _settings() async {
    final n=TextEditingController(text:shopName),a=TextEditingController(text:address),p1=TextEditingController(text:phone1),p2=TextEditingController(text:phone2),w=TextEditingController(text:worker);
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('إعدادات النشاط'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'اسم النشاط')),TextField(controller:a,decoration:const InputDecoration(labelText:'العنوان')),TextField(controller:p1,decoration:const InputDecoration(labelText:'رقم الهاتف الأول')),TextField(controller:p2,decoration:const InputDecoration(labelText:'رقم الهاتف الثاني')),TextField(controller:w,decoration:const InputDecoration(labelText:'اسم العامل / المستخدم'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حفظ'))]));
    if(ok==true){final prefs=await SharedPreferences.getInstance();await prefs.setString('shopName',n.text);await prefs.setString('address',a.text);await prefs.setString('phone1',p1.text);await prefs.setString('phone2',p2.text);await prefs.setString('worker',w.text);await _load();}
  }
  @override Widget build(BuildContext context){
    final pages=[_requestsPage(),_itemsPage(),_settingsPage()];
    return Scaffold(appBar:AppBar(title:Text(shopName),actions:[IconButton(onPressed:_settings,icon:const Icon(Icons.settings))]),body:pages[tab],floatingActionButton:tab==0?FloatingActionButton.extended(onPressed:_addRequest,icon:const Icon(Icons.add),label:const Text('طلب نقص')):tab==1?FloatingActionButton.extended(onPressed:_addItem,icon:const Icon(Icons.add),label:const Text('صنف جديد')):null,bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const [NavigationDestination(icon:Icon(Icons.receipt_long),label:'الطلبات'),NavigationDestination(icon:Icon(Icons.category),label:'الأصناف'),NavigationDestination(icon:Icon(Icons.store),label:'الإعدادات')]));
  }
  Widget _requestsPage()=>RefreshIndicator(onRefresh:_load,child:requests.isEmpty?ListView(children:[const SizedBox(height:150),Center(child:Text('لا توجد طلبات بعد'))]):ListView.builder(itemCount:requests.length,itemBuilder:(c,i){final r=requests[i];return Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:5),child:ListTile(leading:const Icon(Icons.inventory_2_outlined),title:Text(r['itemName'].toString()),subtitle:Text('الكمية: ${r['qty']} • ${r['worker']??''}\n${r['note']??''}'),isThreeLine:true,trailing:PopupMenuButton<String>(initialValue:r['status'] as String, onSelected:(v)async{await AppDb.instance.setStatus(r['id'] as int,v);await _load();},itemBuilder:(c)=>['جديد','قيد التجهيز','تم توفيره','غير متوفر'].map((s)=>PopupMenuItem(value:s,child:Text(s))).toList(),child:Chip(label:Text(r['status'].toString())))));}));
  Widget _itemsPage()=>RefreshIndicator(onRefresh:_load,child:items.isEmpty?ListView(children:[const SizedBox(height:140),const Center(child:Text('لم تتم إضافة أصناف'))]):ListView.builder(itemCount:items.length,itemBuilder:(c,i){final e=items[i];return Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:4),child:ListTile(leading:const Icon(Icons.category_outlined),title:Text(e['name'].toString()),subtitle:Text('التصنيف: ${e['category']} • الوحدة: ${e['unit']}')));}));
  Widget _settingsPage()=>ListView(padding:const EdgeInsets.all(16),children:[(logoPath.isNotEmpty && File(logoPath).existsSync()) ? ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.file(File(logoPath),width:96,height:96,fit:BoxFit.contain)) : const Icon(Icons.storefront,size:64,color:Color(0xff1769aa)),Center(child:Text(shopName,style:Theme.of(context).textTheme.titleLarge)),OutlinedButton.icon(onPressed:_pickLogo,icon:const Icon(Icons.image),label:const Text('اختيار شعار النشاط')),const SizedBox(height:12),ListTile(leading:const Icon(Icons.location_on),title:Text(address.isEmpty?'أضف عنوان النشاط':address)),ListTile(leading:const Icon(Icons.phone),title:Text([phone1,phone2].where((s)=>s.isNotEmpty).join(' • ').isEmpty?'أضف أرقام التواصل':[phone1,phone2].where((s)=>s.isNotEmpty).join(' • '))),ListTile(leading:const Icon(Icons.person),title:Text('المستخدم: $worker')),const SizedBox(height:12),FilledButton.icon(onPressed:_settings,icon:const Icon(Icons.edit),label:const Text('تعديل إعدادات النشاط'))]);
}
