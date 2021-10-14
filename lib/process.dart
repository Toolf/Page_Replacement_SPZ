import 'dart:math';

import 'virtual_page_table.dart';

class PageFault implements Exception {}

class Process {
  final int pid;
  late VirtualPageTable virtualPageTable;
  int ttl;

  late List<VirtualPage> workingSet;
  late List<VirtualPage> otherSet;
  int pageFault = 0;
  int operationDone = 0;

  Process({
    required this.pid,
    required int virtualPageCount,
    required int workingSetSize,
    required this.ttl,
  }) {
    virtualPageTable = VirtualPageTable.generate(
      virtualPageCount,
      (index) => VirtualPage(
        pageNumber: index,
      ),
    );

    workingSet = virtualPageTable.sublist(0, workingSetSize);
    otherSet = virtualPageTable.sublist(workingSetSize);
  }

  void changeWorkingSet([Random? random]) {
    random ??= Random();
    final shuffledVirtualPage = virtualPageTable.sublist(0);
    shuffledVirtualPage.shuffle(random);
    workingSet = shuffledVirtualPage.sublist(0, workingSet.length);
    otherSet = shuffledVirtualPage.sublist(workingSet.length);
  }
}
