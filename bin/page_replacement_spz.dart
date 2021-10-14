import 'dart:io';
import 'dart:math';

import 'package:page_replacement_spz/mmu.dart';
import 'package:page_replacement_spz/page_replacement_algorithm.dart';
import 'package:page_replacement_spz/process.dart';
import 'package:sprintf/sprintf.dart';
import 'package:tabular/tabular.dart';

IOSink? out;

enum SetType {
  working,
  other,
}

enum Operation {
  read,
  write,
}

class System {
  final int maxProcessCount; // максимальна кількість процесів
  final int physicalPageCount; // кількість фізичних сторінок
  final int quant; // квант часу
  final int processCreatingTime; // середній час створення нового процесу
  final int processTTL; // час життя процесу
  final int workingSetSize; // розмір робочого набору
  // кількість операцій після якої треба змінювати робочий набір
  final int changeWoringSetTime;

  late MMU mmu; // memory menagment unit

  System({
    required this.maxProcessCount,
    required this.physicalPageCount,
    required this.quant,
    required this.processCreatingTime,
    required this.processTTL,
    required this.workingSetSize,
    required this.changeWoringSetTime,
  }) {
    mmu = MMU(
      physicalPageCount, // кількість фізичних сторінок
      NRU(), // алгоритм заміщення сторінки
    );
  }

  /// Рандомно виберає віртуальну сторінку певної підгрупи, яка належить процесу.
  int getVirtualPageNumber(Process process, SetType setType, [Random? random]) {
    random ??= Random();

    switch (setType) {
      case SetType.working:
        final s = process.workingSet;
        return s[random.nextInt(s.length)].pageNumber;
      case SetType.other:
        final s = process.otherSet;
        return s[random.nextInt(s.length)].pageNumber;
    }
  }

  void logState(List<Process> processes) {
    if (processes.isNotEmpty) {
      final data = [
            <dynamic>[
              'ProcessId',
              'virtualPageCount',
              'pageFault',
              'TTL',
            ]
          ] +
          List.generate(processes.length, (index) {
            final process = processes[index];
            return <dynamic>[
              process.pid,
              process.virtualPageTable.length,
              process.pageFault,
              process.ttl,
            ];
          });

      out?.writeln(tabular(data));
      out?.writeln();
    }
  }

  logMemoryState(List<Process> processes) {
    out?.writeln("------- Physical Memory --------");
    final data = [
          <dynamic>["Physical Page #", "In used", "Virtual Page #"],
        ] +
        List.generate(
          mmu.physicalMemory.length,
          (index) {
            final physicalPage = mmu.physicalMemory[index];
            return [
              physicalPage.pageNumber,
              physicalPage.inUsed,
              physicalPage.inUsed
                  ? physicalPage.virtualPage!.pageNumber
                  : "NotInUsed"
            ];
          },
        );
    out?.writeln(tabular(data));
    out?.writeln();
  }

  logResult(pageFaultCount, processCount) {
    final globalInforamtion = [
      ["Page fault count", "Process executed count"],
      [pageFaultCount, processCount],
    ];

    out?.writeln(tabular(globalInforamtion));
    out?.writeln();
  }

  /// Моделює роботу процесів за певну кількість тактів
  int simulate([int tacts = 10000]) {
    // Потрібен для повторення симуляції
    final seed = Random().nextInt(10000);
    out?.writeln("Seed: $seed");
    final random = Random(seed);

    int pid = 0; // ідентифікатор слідуючого створеного процесу
    int pageFaultCount = 0; // кількість сторінкових промахів
    int processExecutedCount = 0; // кількість процесів які виконались
    List<Process> processes = []; // запущені процеси в системі

    // частота створення процесів
    final processLaunchFrequncy = (1 / processCreatingTime);

    for (int tact = 0; tact < tacts;) {
      logState(processes); // Логування стану системи
      if (tact % (tacts ~/ 100) == 0) {
        logMemoryState(processes); // Логування стану пам'яті
      }

      int spendTime = min(
        min(quant, tacts - tact),
        processes.isEmpty ? 1 : processes.first.ttl,
      );
      if (processes.isNotEmpty) {
        // Виконання процесу за відведений квант
        final Process process = processes.removeAt(0);
        tact += spendTime;

        for (int processTact = 0; processTact < spendTime; processTact++) {
          // Кожен такт виконуємо операцію

          // визначення типу набору
          final setType =
              random.nextDouble() < 0.9 ? SetType.working : SetType.other;
          // визначення операції
          final operation =
              random.nextDouble() < 0.72 ? Operation.read : Operation.write;

          // визначення віртуальної сторінки
          final virtualPageNumber = getVirtualPageNumber(process, setType);

          switch (operation) {
            case Operation.read:
              mmu.read(
                process,
                virtualPageNumber,
                onPageFault: () {
                  process.pageFault++;
                  pageFaultCount++;
                },
              );
              break;
            case Operation.write:
              mmu.write(
                process,
                virtualPageNumber,
                onPageFault: () {
                  process.pageFault++;
                  pageFaultCount++;
                },
              );
              break;
          }

          // Зміна робочої групи
          process.operationDone++;
          if (process.operationDone % changeWoringSetTime == 0) {
            process.changeWorkingSet(random);
          }

          process.ttl--;
        }

        if (process.ttl != 0) {
          processes.add(process);
        } else {
          // Змільненя всіх віртуальних сторінок процесу
          for (var virtualPage in process.virtualPageTable) {
            mmu.free(virtualPage);
          }
          processExecutedCount++;
        }
      } else {
        tact++;
      }

      // Добавлення нового процесу
      for (int i = 0; i < spendTime; i++) {
        if (processes.length < maxProcessCount &&
            random.nextDouble() <= processLaunchFrequncy) {
          processes.add(
            Process(
              pid: pid++,
              virtualPageCount:
                  workingSetSize + random.nextInt(physicalPageCount ~/ 2) + 1,
              ttl: processTTL,
              workingSetSize: workingSetSize,
            ),
          );
        }
      }
    }

    logResult(pageFaultCount, processExecutedCount);
    return pageFaultCount;
  }
}

void main(List<String> arguments) {
  System system;
  for (int workingSetSize = 1; workingSetSize <= 20; workingSetSize++) {
    out = File('logs/log#$workingSetSize.txt').openWrite();
    double avrPageFault = 0;

    for (int n = 0; n < 20; n++) {
      system = System(
        maxProcessCount: 10,
        physicalPageCount: 50,
        processCreatingTime: 15,
        processTTL: 38,
        quant: 10,
        workingSetSize: workingSetSize,
        changeWoringSetTime: 15,
      );

      avrPageFault += system.simulate(10000);
    }
    avrPageFault /= 20;

    final simulationResult = [
      ["Simulation #", "AvrPageFault %"],
      [
        workingSetSize,
        sprintf("%.2f", [avrPageFault / 10000])
      ],
    ];

    out?.writeln(tabular(simulationResult));
    out?.writeln();
    out?.close();
  }
}
