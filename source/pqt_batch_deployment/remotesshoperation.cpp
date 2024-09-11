#include "remotesshoperation.h"

RemoteSSHOperation::RemoteSSHOperation(QObject* parent)
  : QThread(parent) {
  QObject::connect(
    this, SIGNAL(SI_flashStatus(QString, quint64)), parent,
    SLOT(flashStatus(QString, quint64)), Qt::QueuedConnection);
  QObject::connect(
    this, SIGNAL(SI_comReturn(bool, quint64)), parent, SLOT(comReturn(bool,
        quint64)),
    Qt::QueuedConnection);
  QObject::connect(this,
    SIGNAL(SI_WarningMessage(QString, quint64)),
    parent,
    SLOT(WarningMessage(QString, quint64)), Qt::QueuedConnection);
  QObject::connect(this,
    SIGNAL(SI_returnComLog(QString, quint64)),
    parent,
    SLOT(returnComLog(QString, quint64)), Qt::QueuedConnection);
  QObject::connect(this,
    SIGNAL(SI_flashProgress(double, quint64)),
    parent,
    SLOT(flashProgress(double, quint64)), Qt::QueuedConnection);
}

void RemoteSSHOperation::setInfo(RemoteInfData* inRemoteInf,
  quint64 inThisRemoteId, QDir rootDir) {
  remoteInf = inRemoteInf;
  thisRemoteId = inThisRemoteId;
  localDir = rootDir;
  setFlag = true;
}

void RemoteSSHOperation::run() {
  qint64 re = 0;
  if (!setFlag)
    goto tEnd;
  foreach (OperationInfData* item, operationInfs) {
    re = runOperation(item);
    if (re != STATE_SUCCESS)
      break;
  }
tEnd:
  emit SI_CR((re == STATE_SUCCESS) ? true : false);
}

int RemoteSSHOperation::downFile(QString remoteFilePath,
  QString localFilePath) {
  qint64 bytesRead;
  unsigned long hostaddr;
  int sock, i, auth_pw = 1;
  struct sockaddr_in sin;
  const char* fingerprint;
  LIBSSH2_SESSION* session;
  LIBSSH2_SFTP* sftp_session;
  LIBSSH2_SFTP_HANDLE* sftp_handle;
  LIBSSH2_CHANNEL* channel;
  QFile localFile(localFilePath);
  qint64 read_cnt = 0;
  int re = -1, rc;
  quint64 fileSize, trSize;
  SSH_CONNECT_CODE
  sftp_session = libssh2_sftp_init(session);
  if (!sftp_session) {
    sshWarrning("无法打开stfp");
    goto shutdown_sftp;
  }
  LIBSSH2_SFTP_ATTRIBUTES attributes;
  rc =
    libssh2_sftp_stat(sftp_session, remoteFilePath.toLocal8Bit(), &attributes);
  if (rc != 0) {
    sshWarrning(QString("无法获取远程文件信息: %1").arg(rc));
    goto shutdown_sftp;
  }
  sftp_handle = libssh2_sftp_open(
      sftp_session, remoteFilePath.toLocal8Bit(), LIBSSH2_FXF_READ, 0);
  if (!sftp_handle) {
    sshWarrning("无法打开远程文件");
    goto close_sftp;
  }
  if (!localFile.open(QIODevice::WriteOnly)) {
    sshWarrning("不能打开本地文件");
    goto close_sftp;
  }
  while (0 != libssh2_sftp_fsync(sftp_handle)) {
    sshWarrning("sftp fsync失败，重试中");
    QThread::msleep(200);
  }
  fileSize = attributes.filesize;
  trSize = 0;
  while (1) {
    bytesRead =
      libssh2_sftp_read(sftp_handle, readBuffer, sftpBufferSize);
    if (bytesRead == LIBSSH2_ERROR_EAGAIN) {
      QThread::msleep(100);
      continue;
    }
    else if (bytesRead < 0)
      goto close_sftp;
    else if (bytesRead == 0)
      break;
    else
      localFile.write(readBuffer, bytesRead);
    trSize += bytesRead;
    emit SI_FP((double)trSize / fileSize);
  }
  re = 0;
close_sftp:
  libssh2_sftp_close(sftp_handle);
shutdown_sftp:
  libssh2_sftp_shutdown(sftp_session);
disconnectSession:
  libssh2_session_disconnect(session, "");
freeSession:
  libssh2_session_free(session);
closeSocket:
#ifdef WIN32
  closesocket(sock);
#else
  close(sock);
#endif
  return re;
}

int RemoteSSHOperation::upFile(QString filePath, QString remoteFilePath) {
  qint64 bytesRead;
  unsigned long hostaddr;
  int sock, i, auth_pw = 1;
  struct sockaddr_in sin;
  const char* fingerprint;
  LIBSSH2_SESSION* session;
  LIBSSH2_SFTP* sftp_session;
  LIBSSH2_SFTP_HANDLE* sftp_handle;
  LIBSSH2_CHANNEL* channel;
  QFile localFile(filePath);
  quint64 fileSize, trSize;
  int re = -1;
  SSH_CONNECT_CODE
  sftp_session = libssh2_sftp_init(session);
  if (!sftp_session) {
    sshWarrning("无法打开stfp");
    goto shutdown_sftp;
  }
  sftp_handle =
    libssh2_sftp_open(sftp_session,
      remoteFilePath.toLocal8Bit(),
      LIBSSH2_FXF_WRITE | LIBSSH2_FXF_CREAT | LIBSSH2_FXF_TRUNC,
      LIBSSH2_SFTP_S_IRUSR | LIBSSH2_SFTP_S_IWUSR |
      LIBSSH2_SFTP_S_IRGRP | LIBSSH2_SFTP_S_IROTH);
  if (!sftp_handle) {
    sshWarrning(QString("无法创建远程文件:%1").arg(remoteFilePath));
    goto close_sftp;
  }
  if (!localFile.open(QIODevice::ReadOnly)) {
    sshWarrning("不能打开本地文件");
    goto close_sftp;
  }
  fileSize = localFile.size();
  trSize = 0;
  while ((bytesRead = localFile.read(readBuffer, sftpBufferSize)) > 0) {
    qint64 bytesWrite = 0;
    while (bytesWrite != bytesRead) {
      bytesWrite += libssh2_sftp_write(sftp_handle, readBuffer + bytesWrite,
          bytesRead - bytesWrite);
      libssh2_sftp_fsync(sftp_handle);
    }
    trSize += bytesWrite;
    emit SI_FP((double)trSize / fileSize);
  }
  while (0 != libssh2_sftp_fsync(sftp_handle)) {
    sshWarrning("sftp fsync失败，重试中");
    QThread::msleep(200);
  }
  re = 0;
close_sftp:
  libssh2_sftp_close(sftp_handle);
shutdown_sftp:
  libssh2_sftp_shutdown(sftp_session);
disconnectSession:
  libssh2_session_disconnect(session, "");
freeSession:
  libssh2_session_free(session);
closeSocket:
#ifdef WIN32
  closesocket(sock);
#else
  close(sock);
#endif
  return re;
}

int RemoteSSHOperation::sendCommend(QString sendInfo, QString& reInfo) {
  qint64 bytesRead;
  unsigned long hostaddr;
  int sock, i, auth_pw = 1;
  struct sockaddr_in sin;
  const char* fingerprint;
  LIBSSH2_SESSION* session;
  LIBSSH2_SFTP* sftp_session;
  LIBSSH2_SFTP_HANDLE* sftp_handle;
  LIBSSH2_CHANNEL* channel;
  int re = -1, rc;
  SSH_CONNECT_CODE
  channel = libssh2_channel_open_session(session);
  if (!channel) {
    sshWarrning("无法打开会话");
    goto disconnectSession;
  }
  libssh2_channel_set_blocking(channel, 1);
  rc = libssh2_channel_exec(channel, sendInfo.toLocal8Bit());
  if (rc != 0) {
    sshWarrning("发送指令失败");
    goto disconnectSession;
  }
  reInfo.clear();
  while ((bytesRead = libssh2_channel_read(
          channel, readBuffer, sizeof(readBuffer) - 1)) > 0) {
    readBuffer[bytesRead] = '\0';
    reInfo.append(readBuffer);
  }
  reInfo.replace("\\n", "\n");
  re = 0;
disconnectSession:
  libssh2_session_disconnect(session, "");
freeSession:
  libssh2_session_free(session);
closeSocket:
#ifdef WIN32
  closesocket(sock);
#else
  close(sock);
#endif
  return re;
}

int RemoteSSHOperation::runOperation(OperationInfData* operation) {
  QString remoteLog;
  qint64 rc;
  QString absolutePath;
  QString md5Sum("sync; echo " + remoteInf->passwd + " | sudo -S md5sum ");
  QString md5Str, md5Str2;
  QString currentDateTimeString =
    QDateTime::currentDateTime().toString("yyyy_MM_dd_hh_mm_ss");
  const QString default_file = remoteInf->ip + "_" + QString::number(
      remoteInf->port) + "_" + currentDateTimeString + "_";
  QFileInfo sorceFile = QFileInfo(operation->transferFileSourcePath);
  switch (operation->type) {
  case OperationInfData::operationCommand:
    emit SI_FS(QString("正在执行命令:%1").arg(operation->name));
    emit SSH_CHECK(rc = STATE_ERROR_SSH, sendCommend(operation->commandStr,
        remoteLog), 0, return rc);
    if (!operation->checkErrorStr.isEmpty()) {
      if (remoteLog.contains(operation->checkSuccessStr, Qt::CaseInsensitive)) {
        emit SI_WM(QString("错误:错误关键字log检查符合:%1").arg(
            remoteLog));
        return STATE_ERROR_ERRORLOG;
      }
    }
    if (!operation->checkSuccessStr.isEmpty()) {
      if (remoteLog.contains(operation->checkSuccessStr, Qt::CaseInsensitive)) {
        emit SI_RC(currentDateTimeString + operation->name + '\n' + remoteLog);
        return STATE_SUCCESS;
      }
      else {
        emit SI_WM(QString("错误:成功关键字log检查失败:%1").arg(
            remoteLog));
        return STATE_ERROR_ERRORLOG;
      }
    }
    emit SI_RC(currentDateTimeString + operation->name + '\n' + remoteLog);
    break;
  case OperationInfData::operationUpFile:
    absolutePath = QDir(localDir).absoluteFilePath(
        operation->transferFileSourcePath);
    emit SI_FS("正在上传文件，请稍等");
    emit SFTP_CHECK(rc = STATE_ERROR_SFTP, upFile(absolutePath,
        operation->transferFileDestinationPath), 0, return rc);
    emit SI_FS("正在校验MD5，请稍等");
    emit SSH_CHECK(rc = STATE_ERROR_SSH,
      sendCommend(md5Sum + operation->transferFileDestinationPath,
        remoteLog), 0, return rc);
    md5Str = remoteLog.split(" ").at(0);
    emit SI_RC(currentDateTimeString + operation->name + '\n' +
      "远程MD5计算结果" + '\n' + remoteLog);
    if (md5Str != operation->fileMd5) {
      emit SI_WM(QString("错误:MD5校验失败:[%1] -> [%2]").arg(
          operation->fileMd5,
          md5Str));
      return STATE_ERROR_SFTP;
    }
    emit SI_FS("MD5校验成功");
    break;
  case OperationInfData::operationDownFile:
    absolutePath = QDir::cleanPath(QDir(localDir).absoluteFilePath(
          operation->transferFileDestinationPath) + QDir::separator() +
        QString("%1_%2").arg(default_file).arg(sorceFile.fileName()));
    emit SI_FS("正在下载文件，请稍等");
    emit SFTP_CHECK(rc = STATE_ERROR_SFTP,
      downFile(operation->transferFileSourcePath, absolutePath), 0,
      return rc);
    emit SI_FS("正在校验MD5，请稍等");
    md5Str2 = calculateFileMD5(absolutePath);
    if (md5Str2.isEmpty()) {
      emit SI_WM(QString("错误:本地%1 MD5计算结果为空").arg(absolutePath));
      return STATE_ERROR;
    }
    emit SSH_CHECK(rc = STATE_ERROR_SSH,
      sendCommend(md5Sum + operation->transferFileSourcePath,
        remoteLog), 0, return rc);
    emit SI_RC(currentDateTimeString + operation->name + '\n' +
      "远程MD5计算结果" + '\n' + remoteLog);
    md5Str = remoteLog.split(" ").at(0);
    if (md5Str != md5Str2) {
      emit SI_WM(QString("错误:MD5校验失败:[%1] -> [%2]").arg(
          md5Str, md5Str2));
      return STATE_ERROR_SFTP;
    }
    emit SI_FS("MD5校验成功");
    break;
  default:
    return -1;
    break;
  }
  return STATE_SUCCESS;
}

void RemoteSSHOperation::addOperationInf(OperationInfData* operationInf) {
  if (operationInf->status == false)
    return;
  operationInfs.append(operationInf);
}

QString RemoteSSHOperation::calculateFileMD5(const QString& filePath) {
  QFile file(filePath);
  qDebug() << "计算MD5文件 " << filePath;
  if (!file.open(QIODevice::ReadOnly)) {
    qDebug() << "Failed to open file.";
    return QString();
  }
  QCryptographicHash hash(QCryptographicHash::Md5);
  if (hash.addData(&file)) {
    QByteArray md5 = hash.result();
    qDebug() << "计算MD5: " << md5.toHex();
    return md5.toHex();
  }
  else {
    qDebug() << "Failed to calculate MD5.";
    return QString();
  }
}
