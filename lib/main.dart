//  ignore_for_file: avoid_print
import 'package:dropdown_textfield/dropdown_textfield.dart';
import 'package:file_picker/file_picker.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:image/image.dart' as im;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:photo_gallery/photo_gallery.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  runApp(Phoenix(child: const MyApp()));

}


void onStart() async {

  int prevLen = 12893;

  WidgetsFlutterBinding.ensureInitialized();
  final service = FlutterBackgroundService();

  Future<void> resizeImage(File image) async {
    print(image.path);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    print(prefs.getInt('bHeight'));
    int? bh = prefs.getInt('bHeight')!;
    im.Image? img = im.decodeJpg(File(image.path).readAsBytesSync());
    im.Image thumbnail = im.copyResize(img!, width: ((bh/100)*img.width).round(), height: ((bh/100)*img.height).round());
    final f = await File('/data/user/0/com.example.photo_resizer/cache/y${DateTime.now()}.jpg').writeAsBytes(im.encodeJpg(thumbnail));
    ImageGallerySaver.saveFile(f.path).then((value) => print('Saved ✅'));
    File(image.path).deleteSync();


  }

  Future<MediaPage> getImagesFromGallery() async {

    final List<Album> imageAlbums = await PhotoGallery.listAlbums(
      mediumType: MediumType.image,
    );
    final MediaPage imagePage = await (imageAlbums.where((element) => element.name == 'Camera')).toList()[0].listMedia();
    print((await imagePage.items.last.getFile()).path);
    return imagePage;
  }

  service.onDataReceived.listen((event) async {
    print(event!);
    if (event.containsKey('action')) {
      while(true){
        print('something');
        getImagesFromGallery().then((value) async {
          if (value.items.length > prevLen) {
            await resizeImage((await value.items.last.getFile()));
            service.setNotificationInfo(
              title: "Running",
              content: "Updated at ${DateTime.now()}",
            );
          }
          prevLen = value.items.length ;
        });
        await Future.delayed(const Duration(seconds: 10));
      }
    }
  });
}


class MyApp extends StatefulWidget {

  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {


  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHome()
    );
  }
}

class MyHome extends StatefulWidget {
  const MyHome({Key? key}) : super(key: key);

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {

  bool _loading = false;
  List _albums = [];

  @override
  void initState() {
    super.initState();
    _loading = true;
    initAsync();
    requestPermission();
    FlutterBackgroundService.initialize(onStart);
  }

  void requestPermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    var status1 = await Permission.manageExternalStorage.status;
    if (!status1.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> initAsync() async {
    if (await _promptPermissionSetting()) {
      List<Album> albums =
      await PhotoGallery.listAlbums(mediumType: MediumType.image);
      setState(() {
        _albums = albums;
        _loading = false;
      });
    }
    setState(() {
      _loading = false;
    });
  }

  Future<bool> _promptPermissionSetting() async {
    if (Platform.isIOS && await Permission.storage.request().isGranted &&
        await Permission.photos.request().isGranted ||
        Platform.isAndroid && await Permission.storage.request().isGranted && await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }
    return false;
  }

  SingleValueDropDownController bHeightController = SingleValueDropDownController();
  SingleValueDropDownController heightController = SingleValueDropDownController();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.black87,
          title: const Text('Image Resizer', style: TextStyle(color: Colors.white),),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14,),
              const Text('Set Resize Parameter', style: TextStyle(fontSize: 16)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: DropDownTextField(
                  controller: bHeightController,
                  searchDecoration: const InputDecoration(
                      hintText: 'Select Size'
                  ),
                  clearOption: true,
                  enableSearch: true,
                  dropDownItemCount: 100,
                  dropDownList: [
                    for (int i = 10; i <= 100; i+=10)
                      DropDownValueModel(name: '$i%', value: i.toString())
                  ],
                ),
              ),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    FlutterBackgroundService().sendData({
                      "noAction": "noAction"
                    });
                    print(bHeightController.dropDownValue!.value);
                    await prefs.setInt('bHeight', int.parse(bHeightController.dropDownValue!.value));
                    FlutterBackgroundService().sendData({
                      "action": "action"
                    });
                  },
                  child: const Text('Set'),
                ),
              ),
              const SizedBox(height: 40,),
              const Text('Crop an Image from Gallery', style: TextStyle(fontSize: 16),),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: DropDownTextField(
                  controller: heightController,
                  searchDecoration: const InputDecoration(
                      hintText: 'Select Size'
                  ),
                  clearOption: true,
                  enableSearch: true,
                  dropDownItemCount: 100,
                  dropDownList: [
                    for (int i = 10; i <= 100; i+=10)
                      DropDownValueModel(name: '$i%', value: i.toString())
                  ],
                ),
              ),
              Center(
                child: ElevatedButton(onPressed: () async {
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('height', int.parse(heightController.dropDownValue!.value));
                  // final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
                  Directory appDocDir = Directory("storage/emulated/0");
                  var result = await FilesystemPicker.open(fsType: FilesystemType.file ,allowedExtensions: [".png", ".jpg"],rootDirectory: appDocDir, context: context);
                  if (result != null) {
                    File file = File(result);
                    print(file.parent.path); //// the path where the file is saved
                    print(file.absolute.path);

                    im.Image? image = im.decodeJpg(File(file.absolute.path).readAsBytesSync());
                    int h = prefs.getInt('height')!;
                    im.Image thumbnail = im.copyResize(image!, width: ((h/100)*image.width).round(), height: ((h/100)*image.height).round());
                    final f = await File('/data/user/0/com.example.photo_resizer/cache/y${DateTime.now()}.png').writeAsBytes(im.encodePng(thumbnail));
                    ImageGallerySaver.saveFile(f.path);
                    File(file.absolute.path).deleteSync();
                  }
                }, child: const Text('Choose and Crop')),
              )
            ],
          ),
        )
    );
  }
}
