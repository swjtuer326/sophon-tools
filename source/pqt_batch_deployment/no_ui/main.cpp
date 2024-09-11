#include <QCoreApplication>
#include <QDebug>
#include <QFileInfo>
#include "argsparse.h"



int main(int argc, char* argv[]) {
  QCoreApplication a(argc, argv);
  ArgsParse ap;
  ap.mainProcess();
  return a.exec();
}
