import 'physical_memory.dart';

abstract class PageReplacementAlgorithm {
  PhysicalPage getPageForReplace(PhysicalMemory physicalMemory);
}

class NRU implements PageReplacementAlgorithm {
  @override
  PhysicalPage getPageForReplace(PhysicalMemory physicalMemory) {
    final virtualPages = physicalMemory.map((p) => p.virtualPage!).toList();

    final needToBeReplace = virtualPages.firstWhere(
      (p) => !p.R && !p.M,
      orElse: () {
        return virtualPages.firstWhere(
          (p) => !p.R && p.M,
          orElse: () {
            return virtualPages.firstWhere(
              (p) => p.R && !p.M,
              orElse: () {
                return virtualPages.firstWhere(
                  (p) => p.R && p.M,
                );
              },
            );
          },
        );
      },
    );
    for (var p in virtualPages) {
      p.referenceBit = false;
    }
    return physicalMemory[needToBeReplace.physicalPageNumber!];
  }
}
