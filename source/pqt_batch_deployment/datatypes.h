#ifndef DATATYPES_H
#define DATATYPES_H

#include <QObject>
#include <QDebug>

#include "version.h"

class RemoteInfData : public QObject {
  Q_OBJECT
 public:
  RemoteInfData(QString inIp, quint64 inPort, QString inUser, QString inPasswd,
    QObject* parent = nullptr): ip(inIp), port(inPort), user(inUser),
    passwd(inPasswd), QObject(parent) {};
  RemoteInfData(const RemoteInfData& data): ip(data.ip), port(data.port),
    user(data.user), passwd(data.passwd), QObject(data.parent()) {};

  QString ip;
  quint64 port;
  QString user;
  QString passwd;

 signals:

};

class OperationInfData : public QObject {
  Q_OBJECT
 public:
  enum operationType {
    operationCommand = 0,
    operationUpFile,
    operationDownFile
  };
  Q_ENUM(operationType)
  QStringList operationTypeStrList = QStringList({"下发命令", "上传文件", "下载文件", "Retrieve"});
  QString operationTypeString() {
    return operationTypeStrList.at(type);
  }

  enum checkFileMethods {
    checkFileMd5 = 0,
    checkFileSize,
    noCheck
  };
  Q_ENUM(checkFileMethods)
  QStringList checkFileStrList = QStringList({"MD5校验值", "文件大小校验", "不进行校验"});
  QString checkFileString() {
    return checkFileStrList.at(checkFile);
  }

  OperationInfData(QString name, operationType type, QString commandStr,
    QString checkSuccessStr = "", QString checkErrorStr = "",
    QObject* parent = nullptr): name(name), type(type),
    commandStr(commandStr), checkSuccessStr(checkSuccessStr),
    checkErrorStr(checkErrorStr), QObject(parent) {
    if (type != operationCommand) {
      status = false;
      qDebug() << "operationInfData operationCommand error: " << type;
    }
  };
  OperationInfData(QString name, operationType type,
    QString transferFileSourcePath,
    QString transferFileDestinationPath, checkFileMethods checkFile = noCheck,
    QObject* parent = nullptr): name(name), type(type),
    checkFile(checkFile), transferFileSourcePath(transferFileSourcePath),
    transferFileDestinationPath(transferFileDestinationPath), QObject(parent) {
    if ((type != operationUpFile) && (type != operationDownFile)) {
      status = false;
      qDebug() << "operationInfData operationFile error: " << type;
    }
  };
  OperationInfData(const OperationInfData& data): name(data.name),
    type(data.type),
    commandStr(data.commandStr), checkSuccessStr(data.checkSuccessStr),
    transferFileSourcePath(data.transferFileSourcePath),
    checkErrorStr(data.checkErrorStr), checkFile(data.checkFile),
    status(data.status),
    transferFileDestinationPath(data.transferFileDestinationPath),
    QObject(data.parent()) {};
  void checkStatus(void) {
    switch (type) {
    case operationCommand:
      if (commandStr.isEmpty() || name.isEmpty())
        status = false;
      else
        status = true;
      break;
    case operationUpFile:
    case operationDownFile:
      if (transferFileSourcePath.isEmpty() || transferFileDestinationPath.isEmpty()
        || name.isEmpty())
        status = false;
      else
        status = true;
      break;
    }
  }

  QString name = "";
  operationType type = operationCommand;
  QString commandStr = "";
  QString checkSuccessStr = "";
  QString checkErrorStr = "";
  QString transferFileSourcePath = "";
  QString transferFileDestinationPath = "";
  QString fileMd5 = "";
  checkFileMethods checkFile = checkFileMd5;
  bool status = true;

 signals:

};

#endif // DATATYPES_H
