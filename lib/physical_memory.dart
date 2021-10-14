import 'virtual_page_table.dart';

class PhysicalPage {
  int pageNumber;
  bool get inUsed => virtualPage != null;
  VirtualPage? virtualPage;

  PhysicalPage({
    required this.pageNumber,
  });
}

typedef PhysicalMemory = List<PhysicalPage>;
