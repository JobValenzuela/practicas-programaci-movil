import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class CsvNodeManager {
  List<List<dynamic>> importedRows = [];

  // Convierte los nodos a CSV y agrega un checksum SHA-256 para verificar su integridad.
  // Guarda el archivo en documentos o abre el diálogo para guardarlo en la web.
  Future<String> exportNodesToCsv(List<List<dynamic>> rows) async {
    String csvData = const ListToCsvConverter().convert(rows);

    var bytes = utf8.encode(csvData);
    var checksum = sha256.convert(bytes).toString();

    String fileContent = "# CHECKSUM:$checksum\n$csvData";
    if (kIsWeb) {
      await FilePicker.platform.saveFile(
        fileName: 'iot_nodes_config.csv',
        bytes: Uint8List.fromList(utf8.encode(fileContent)),
      );
      return 'iot_nodes_config.csv';
    }
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/iot_nodes_config.csv';
    final file = File(filePath);
    await file.writeAsString(fileContent);
    return filePath;
  }

  // Lee el CSV desde sus bytes o su ruta y compara el checksum con el contenido.
  // Si coincide, carga las filas en importedRows y devuelve true.
  Future<bool> verifyAndImportCsv(String filePath, {Uint8List? bytes}) async {
    importedRows = [];
    String fileContent;
    if (bytes != null) {
      fileContent = utf8.decode(bytes);
    } else {
      if (kIsWeb) return false;
      final file = File(filePath);
      if (!await file.exists()) return false;
      fileContent = await file.readAsString();
    }
    int firstNewline = fileContent.indexOf('\n');
    if (firstNewline < 0) return false;
    String header = fileContent.substring(0, firstNewline);
    if (!header.startsWith("# CHECKSUM:")) return false;

    String originalChecksum = header.replaceFirst("# CHECKSUM:", "").trim();
    String csvBody = fileContent.substring(firstNewline + 1);

    var recalculatedChecksum = sha256.convert(utf8.encode(csvBody)).toString();

    if (originalChecksum == recalculatedChecksum) {
      List<List<dynamic>> parsedCsv = const CsvToListConverter(
        shouldParseNumbers: false,
        allowInvalid: false,
      ).convert(csvBody);
      importedRows = parsedCsv;
      print("Datos de nodos válidos cargados correctamente: $parsedCsv");
      return true;
    } else {
      print("ALERTA DE SEGURIDAD: El archivo CSV ha sido alterado o corrupto.");
      return false;
    }
  }
}
