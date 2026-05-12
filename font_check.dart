import 'package:google_fonts/google_fonts.dart';
void main() {
  print(GoogleFonts.asMap().keys.where((k) => k.toLowerCase().contains('playwrite')).toList());
}
