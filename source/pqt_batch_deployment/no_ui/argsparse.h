#ifndef ARGSPARSE_H
#define ARGSPARSE_H
#include <QObject>
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QList>

#include "../remotesshoperation.h"
#include "../datatypes.h"


class ArgsParse : public QObject {
  Q_OBJECT
 public:
  ArgsParse();
  ~ArgsParse();

  void getArgs();
  void echoHelp(QString name);
  QString getRootDirectory();
  QString getJsonFilePath();
  void checkRD(QString file_path);
  void checkJS(QString file_path);
  void parseJson();
  void sshProcess();
  void startProcess();
  void fullProcess();
  void mainProcess();
  void checkBS(QString batch_size);
  void md5SumAll();
  QString calculateFileMD5(const QString& filePath);

 private:
  QString _RootDirectory;
  QString _JsonFilePath;
  RemoteInfData* remoteData;
  OperationInfData* operationData;
  QString _CommandName;

  QList<RemoteInfData*> sshInfoList;
  QList<OperationInfData*> optInfoList;
  QDir localDir;
  quint64 remoteNum = 0;
  quint64 closeNum = 0;
  quint64 startNum = 0;
  quint64 batchSize = 100;
  quint64 curMaxBatch = 0;
  QVector<QString> resultStore;
  QVector<QString> resultStatus;


 public slots:
  void flashStatus(QString status, quint64 id = 0);
  void comReturn(bool ok, quint64 id = 0);
  void WarningMessage(QString message, quint64 id = 0);
  void returnComLog(QString message, quint64 id = 0);
  void flashProgress(double progress, quint64 id = 0);
};

#endif // ARGSPARSE_H
