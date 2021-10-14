import 'dart:typed_data';

import 'virtual_page_table.dart';

import 'page_replacement_algorithm.dart';
import 'process.dart';
import 'physical_memory.dart';

class MMU {
  late PhysicalMemory physicalMemory;
  final PageReplacementAlgorithm pageReplacementAlgorithm;

  MMU(
    int physicalPageCount,
    this.pageReplacementAlgorithm,
  ) {
    physicalMemory = List.generate(
      physicalPageCount,
      (index) => PhysicalPage(
        pageNumber: index,
      ),
    );
  }

  int _getFreePhysicalPageNumber(int pid, [Function? onPageFault]) {
    return physicalMemory.firstWhere(
      (p) => !p.inUsed,
      orElse: () {
        final physicalPage = pageReplacementAlgorithm.getPageForReplace(
          physicalMemory,
        );

        // load physical page to swap file
        physicalPage.virtualPage!.modificationBit = false;

        physicalPage.virtualPage!.referenceBit = false;
        physicalPage.virtualPage!.presenceBit = false;
        physicalPage.virtualPage!.physicalPageNumber = null;
        physicalPage.virtualPage = null;

        onPageFault?.call();
        return physicalPage;
      },
    ).pageNumber;
  }

  int _getPhysicalPageNumber(
    int pid,
    VirtualPage virtualPage, [
    Function? onPageFault,
  ]) {
    if (virtualPage.presenceBit) {
      return virtualPage.physicalPageNumber as int;
    } else {
      final phsyicalPageNumber = _getFreePhysicalPageNumber(pid, onPageFault);
      physicalMemory[phsyicalPageNumber].virtualPage = virtualPage;
      virtualPage.physicalPageNumber = phsyicalPageNumber;
      virtualPage.presenceBit = true;
      return phsyicalPageNumber;
    }
  }

  void free(VirtualPage virtualPage) {
    if (virtualPage.presenceBit) {
      final physicalPage = physicalMemory[virtualPage.physicalPageNumber!];
      physicalPage.virtualPage = null;

      virtualPage.presenceBit = false;
      virtualPage.modificationBit = false;
      virtualPage.referenceBit = false;
      virtualPage.physicalPageNumber = null;
    }
  }

  read(
    Process process,
    int virtualPageNumber, {
    Function? onPageFault,
  }) {
    final virtualPage = process.virtualPageTable[virtualPageNumber];
    final int physicalPageNumber = _getPhysicalPageNumber(
      process.pid,
      virtualPage,
      onPageFault,
    );

    virtualPage.referenceBit = true;
    return _readFromPhysicalPage(physicalPageNumber);
  }

  _readFromPhysicalPage(int physicalPageNumber) {
    // Does not need to implement
  }

  write(
    Process process,
    int virtualPageNumber, {
    Function? onPageFault,
    Uint8List? data,
  }) {
    final virtualPage = process.virtualPageTable[virtualPageNumber];
    final int physicalPageNumber = _getPhysicalPageNumber(
      process.pid,
      virtualPage,
      onPageFault,
    );

    virtualPage.modificationBit = true;
    virtualPage.referenceBit = true;
    return _writeToPhysicalPage(physicalPageNumber, data);
  }

  _writeToPhysicalPage(
    int physicalPageNumber, [
    Uint8List? data,
  ]) {
    // Does not need to implement
  }
}
