#ifndef REMOTESSHOPERATION_H
#define REMOTESSHOPERATION_H

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QString>
#include <QThread>
#include <QObject>
#include <QList>
#include <QCryptographicHash>

#include "datatypes.h"

#include <libssh2.h>
#include <libssh2_publickey.h>
#include <libssh2_sftp.h>
#ifdef WIN32
  #include <Winsock2.h>
#else
  #include <arpa/inet.h>
  #include <netinet/in.h>
#endif

class RemoteSSHOperation : public QThread {
  Q_OBJECT
 public:
  explicit RemoteSSHOperation(QObject* parent = nullptr);
  void setInfo(RemoteInfData* remoteInf, quint64 inThisRemoteId, QDir rootDir);
  void run() override;
  int upFile(QString filePath, QString remoteFilePath);
  int downFile(QString remoteFilePath, QString localFilePath);
  int sendCommend(QString sendInfo, QString& reInfo);
  int runOperation(OperationInfData* operation);
  void addOperationInf(OperationInfData* operationInf);
  QString calculateFileMD5(const QString& filePath);

#define SSH_CHECK(_FLU,_F, _RE, _COM)                                               \
  {                                 \
    _FLU;                                                                            \
    QThread::msleep(100);                                                      \
    if (_RE != _F) {                                                           \
      emit SI_WM(QString("发生SSH错误:%1\n请检查参数和目标环境").arg(warringInfo));             \
      _COM;                                                                    \
    }                                                                          \
  }
#define SFTP_CHECK(_FLU,_F, _RE, _COM)                                              \
  {                   \
    _FLU;                                                                    \
    QThread::msleep(100);                                                      \
    if (_RE != _F) {                                                           \
      emit SI_WM(QString("发生SFTP错误:%1\n请检查参数和目标环境").arg(warringInfo));            \
      _COM;                                                                    \
    }                                                                          \
  }
#define SI_WM(_STR) {emit SI_WarningMessage(_STR,thisRemoteId);}
#define SI_FS(_STR) {emit SI_flashStatus(_STR,thisRemoteId);}
#define SI_CR(_BOOL) {emit SI_comReturn(_BOOL,thisRemoteId);}
#define SI_RC(_STR) {emit SI_returnComLog(_STR,thisRemoteId);}
#define SI_FP(_STR) {emit SI_flashProgress(_STR,thisRemoteId);}
  void sshWarrning(QString info) {
    warringInfo = info;
    qWarning() << info;
  };

#define SSH_CONNECT_CODE \
  hostaddr = inet_addr(remoteInf->ip.toLocal8Bit()); \
  sin.sin_family = AF_INET; \
  sin.sin_port = htons(remoteInf->port); \
  sin.sin_addr.s_addr = hostaddr; \
  sock = socket(AF_INET, SOCK_STREAM, 0); \
  if (sock == -1) { \
    sshWarrning("无法创建SOCKET连接"); \
    return re; \
  } \
  if (::connect(sock, (struct sockaddr*)(&sin), sizeof(struct sockaddr_in)) != \
    0) { \
    sshWarrning("连接到远程目标失败"); \
    goto closeSocket; \
  } \
  qDebug("SOCKET链接成功!"); \
  session = libssh2_session_init(); \
  if (libssh2_session_handshake(session, sock)) { \
    sshWarrning("无法初始化SSH会话"); \
    goto freeSession; \
  } \
  if (libssh2_userauth_password( \
      session, remoteInf->user.toLocal8Bit(), remoteInf->passwd.toLocal8Bit())) { \
    sshWarrning("身份验证失败"); \
    goto freeSession; \
  } \
  else \
    qDebug("身份验证成功"); \

  quint64 thisRemoteId = 0;
  RemoteInfData* remoteInf;
  QList<OperationInfData*> operationInfs;
  bool setFlag = false;
  QDir localDir;
  char readBuffer[1024 * 1024 * 10];
  const qint64 sftpBufferSize = 1024 * 1024;
  QString warringInfo;
  const qint64 STATE_ERROR = -1;
  const qint64 STATE_ERROR_SSH = -2;
  const qint64 STATE_ERROR_SFTP = -3;
  const qint64 STATE_ERROR_ERRORLOG = -4;
  const qint64 STATE_ERROR_WARNINGINF = -5;
  const qint64 STATE_SUCCESS = 0;
 signals:
  void SI_flashStatus(QString status, quint64 id);
  void SI_comReturn(bool ok, quint64 id);
  void SI_WarningMessage(QString message, quint64 id);
  void SI_returnComLog(QString message, quint64 id);
  void SI_flashProgress(double progress, quint64 id);
};

#endif // REMOTESSHOPERATION_H
