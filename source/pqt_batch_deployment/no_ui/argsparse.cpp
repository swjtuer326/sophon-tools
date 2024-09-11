#include "argsparse.h"

ArgsParse::ArgsParse() {
#ifdef WIN32
  WSADATA wsadata;
  int err;
  err = WSAStartup(MAKEWORD(2, 0), &wsadata);
  if (err != 0) {
    qWarning("WSAStartup failed with error: %d\n", err);
    exit(-1);
  }
#endif
}

ArgsParse::~ArgsParse() {
#ifdef WIN32
  WSACleanup();
#endif
}

void ArgsParse::echoHelp(QString name) {
  qDebug() <<
    "Usage: " << name << " [Root Directory] [Json File Path] [Max Value]";
  qDebug() << "Arguments:";
  qDebug() <<
    "     Root Directory: The root directory for file related operations, which should be an absolute path";
  qDebug() <<
    "     Json File Path: The configuration file path, which should be an absolute path";
  qDebug() <<
    "     Max Value: The maximum number of parallel, which be greater than 0 and the default value is 100";
}

void ArgsParse::getArgs() {
  QStringList args = QCoreApplication::arguments();
  if (args.count() != 3 && args.count() != 4) {
    echoHelp(args[0]);
    exit(0);
  }
  _CommandName = args[0];
  QString rd = args[1];
  QString js = args[2];
  checkRD(rd);
  checkJS(js);
  if (args.count() == 4) {
    QString bs = args[3];
    checkBS(bs);
  }
  _RootDirectory = rd;
  _JsonFilePath = js;
}

QString ArgsParse::getRootDirectory() {
  return _RootDirectory;
}

QString ArgsParse::getJsonFilePath() {
  return _JsonFilePath;
}

void ArgsParse::checkRD(QString file_path) {
  QDir fi(file_path);
  if (!fi.exists()) {
    qDebug() << "Root directory does not exist";
    echoHelp(_CommandName);
    exit(0);
  }
}

void ArgsParse::checkJS(QString file_path) {
  QFileInfo fi(file_path);
  if (!fi.exists()) {
    qDebug() << "Json file does not exist";
    echoHelp(_CommandName);
    exit(0);
  }
}

void ArgsParse::checkBS(QString batch_size) {
  bool isInt;
  batchSize = batch_size.toInt(&isInt);
  if (!isInt) {
    qDebug() << "This argument is not int";
    echoHelp(_CommandName);
    exit(0);
  }
  else if (batchSize <= 0) {
    qDebug() << "Invaild value for number of parallel, it should be greater than 1";
    echoHelp(_CommandName);
    exit(0);
  }
}

void ArgsParse::parseJson() {
  localDir = _RootDirectory;
  qDebug() << _RootDirectory;
  QFile file(_JsonFilePath);
  if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
    QByteArray jsonData = file.readAll();
    file.close();
    QJsonDocument jsonDoc = QJsonDocument::fromJson(jsonData);
    if (jsonDoc.isObject()) {
      QJsonObject jsonObject = jsonDoc.object();
      if (jsonObject.contains("remoteInf") && jsonObject["remoteInf"].isArray()) {
        QJsonArray jsonArray = jsonObject["remoteInf"].toArray();
        for (int i = 0; i < jsonArray.size(); i++) {
          QJsonObject remoteInfo = jsonArray[i].toObject();
          remoteData = new RemoteInfData(remoteInfo["IP"].toString(),
            remoteInfo["Port"].toInt(),
            remoteInfo["Username"].toString(), remoteInfo["Password"].toString());
          sshInfoList.append(remoteData);
        }
        if (sshInfoList.size() <= 0) {
          qDebug() << "There is no device infomation";
          exit(0);
        }
        qDebug() << "Table data read from" << _JsonFilePath;
      }
      else
        qDebug() << "Invalid JSON data in file";
      if (jsonObject.contains("operationInf")
        && jsonObject["operationInf"].isArray()) {
        QJsonArray jsonArray = jsonObject["operationInf"].toArray();
        for (int i = 0; i < jsonArray.size(); i++) {
          QJsonObject remoteInfo = jsonArray[i].toObject();
          if (remoteInfo["type"].toInt() == 0) {
            operationData = new OperationInfData(
              remoteInfo["name"].toString(),
              (OperationInfData::operationType)remoteInfo["type"].toInt(),
              remoteInfo["commandStr"].toString(),
              remoteInfo["checkSuccessStr"].toString(),
              remoteInfo["checkErrorStr"].toString());
          }
          else {
            QDir relPath = remoteInfo["transferFileSourcePath"].toString();
            QString absPath = relPath.absolutePath();
            operationData = new OperationInfData(
              remoteInfo["name"].toString(),
              (OperationInfData::operationType)remoteInfo["type"].toInt(),
              remoteInfo["transferFileSourcePath"].toString(),
              remoteInfo["transferFileDestinationPath"].toString(),
              (OperationInfData::checkFileMethods)remoteInfo["checkFile"].toInt());
          }
          optInfoList.append(operationData);
        }
        if (optInfoList.size() <= 0) {
          qDebug() << "These is no operation information";
          exit(0);
        }
        qDebug() << "Table data read from" << _JsonFilePath;
      }
    }
  }
}


void ArgsParse::sshProcess() {
  if (curMaxBatch + batchSize >= remoteNum)
    curMaxBatch = remoteNum;
  else
    curMaxBatch += batchSize;
  for (startNum; startNum < curMaxBatch; startNum++) {
    RemoteSSHOperation* remoteSSH = new RemoteSSHOperation(this);
    for (int j = 0; j < optInfoList.size(); j++)
      remoteSSH->addOperationInf(optInfoList[j]);
    remoteSSH->setInfo(sshInfoList[startNum], startNum, localDir);
    remoteSSH->start();
  }
}

void ArgsParse::comReturn(bool ok, quint64 id) {
  closeNum += 1;
  QString tempText;
  tempText += ok ? "成功" : "错误";
  resultStatus[id] += tempText;
  if (closeNum == sshInfoList.size()) {
    for (qint64 i = 0; i < resultStore.size(); i++) {
      qDebug() << "\n========================================================";
      qDebug().noquote() << "设备:" << sshInfoList[i]->ip + ":" + QString::number(
          sshInfoList[i]->port) << "执行结果如下:";
      qDebug().noquote() << "设备ID:" << QString::number(i + 1);
      qDebug().noquote() << resultStore[i];
    }
    qDebug() << "========================================================";
    for (qint64 i = 0; i < resultStatus.size(); i++) {
      //qDebug() << "设备ID" << resultStatus[i];
      QString devID = "设备[" + QString::number(i + 1) + "]";
      QString devInfo = "设备IP: " + sshInfoList[i]->ip + ":" + QString::number(
          sshInfoList[i]->port);
      QString resInfo = "执行状态: " + resultStatus[i];
      qDebug().noquote() << QString("%1%2%3").arg(devID, devID.size()).arg(devInfo,
          devInfo.size() + 5).arg(resInfo, resInfo.size() + 5);
    }
    qDebug() << "========================================================";
    exit(0);
  }
  sshProcess();
}

void ArgsParse::flashStatus(QString status, quint64 id) {
  qDebug().noquote() << "flashStatus: " << "设备" + sshInfoList[id]->ip + ":" +
    QString::number(sshInfoList[id]->port) + " ID:[" + QString::number(
      id + 1) + "] " + status;
}

void ArgsParse::flashProgress(double progress, quint64 id) {
}

void ArgsParse::WarningMessage(QString message, quint64 id) {
}

void ArgsParse::returnComLog(QString message, quint64 id) {
  resultStore[id] += message;
}

void ArgsParse::startProcess() {
  remoteNum = sshInfoList.size();
  for (qint64 i = 0; i < remoteNum; i++) {
    resultStore.append("");
    resultStatus.append("");
  }
  closeNum = 0;
  startNum = 0;
  md5SumAll();
  sshProcess();
}

void ArgsParse::mainProcess() {
  getArgs();
  parseJson();
  startProcess();
}


QString ArgsParse::calculateFileMD5(const QString& filePath) {
  qDebug() << "file path is: " + filePath;
  QFile file(filePath);
  if (!file.open(QIODevice::ReadOnly)) {
    qDebug() << "Failed to open file.";
    return QString();
  }
  QCryptographicHash hash(QCryptographicHash::Md5);
  if (hash.addData(&file)) {
    QByteArray md5 = hash.result();
    return md5.toHex();
  }
  else {
    qDebug() << "Failed to calculate MD5.";
    return QString();
  }
}

void ArgsParse::md5SumAll() {
  qint64 operationNum = optInfoList.count();
  for (int rowOperation = 0; rowOperation < operationNum; ++rowOperation) {
    operationData = optInfoList[rowOperation];
    if (operationData->type == OperationInfData::operationUpFile) {
      qDebug() << "opt path is " + operationData->transferFileSourcePath;
      QString absolutePath = QDir::cleanPath(QDir(localDir).absoluteFilePath(
            operationData->transferFileSourcePath));
      QString md5Str = calculateFileMD5(absolutePath);
      qDebug() << "md5sum " << absolutePath << " -> " << md5Str;
      operationData->fileMd5 = md5Str;
    }
  }
}
