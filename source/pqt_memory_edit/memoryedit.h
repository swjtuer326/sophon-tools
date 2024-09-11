#ifndef MEMORYEDIT_H
#define MEMORYEDIT_H

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QObject>
#include <QString>
#include <QThread>
#include <QWidget>

#include <libssh2.h>
#include <libssh2_publickey.h>
#include <libssh2_sftp.h>
#ifdef WIN32
  #include <Winsock2.h>
#else
  #include <arpa/inet.h>
  #include <netinet/in.h>
#endif

class MemoryEdit : public QThread {
  Q_OBJECT
 public:
  MemoryEdit(QWidget* iparent);
  ~MemoryEdit();
  QWidget* parent;
  typedef struct {
    quint64 npu_mem;
    quint64 vpu_mem;
    quint64 vpp_mem;
    bool vpu_mem_to_npuvpp_flag;
  } memInfoStruct;
  void setLoginInfo(QString ip,
    quint64 port,
    QString iuser,
    QString ipasswd,
    QDir ilocalDir,
    qint64 icom,
    quint64 id = 0,
    bool inautoRestart = false) {
    remoteIp = ip;
    remotePort = port;
    user = iuser;
    passwd = ipasswd;
    localDir = ilocalDir;
    com = icom;
    thisThreadId = id;
    autoRestart = inautoRestart;
    qDebug() << "add new Thread" << remoteIp <<  " " << remotePort << " " << user <<
      " " << passwd << " " << localDir <<  " " << com << " " << thisThreadId << " " <<
      autoRestart;
  };
  void run() override;

  QString remoteIp = "";
  QString user = "";
  QString passwd = "";
  quint64 remotePort = 0;
  QDir localDir;
  qint64 com = 0; /* 0 for p, 1 for c */
  quint64 thisThreadId = 0;
  bool autoRestart;
  const qint64 STATE_ERROR = -1;
  const qint64 STATE_ERROR_SSH = -2;
  const qint64 STATE_ERROR_SFTP = -3;
  const qint64 STATE_ERROR_ERRORINF = -4;
  const qint64 STATE_ERROR_WARNINGINF = -5;
  const qint64 STATE_SUCCESS = 0;
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
#define SI_WM(_STR) {emit SI_WarningMessage(_STR,thisThreadId);}
#define SI_FS(_STR) {emit SI_flashStatus(_STR,thisThreadId);}
#define SI_CR(_BOOL) {emit SI_comReturn(_BOOL,thisThreadId);}
#define SI_RC(_STR) {emit SI_returnComLog(_STR,thisThreadId);}
#define SI_FP(_STR) {emit SI_flashProgress(_STR,thisThreadId);}
  memInfoStruct memMax = {0, 0, 0, false};
  memInfoStruct memNow = {0, 0, 0, false};
  memInfoStruct memSet = {0, 0, 0, false};
 signals:
  void SI_flashInfo(MemoryEdit::memInfoStruct* max,
    MemoryEdit::memInfoStruct* now);
  void SI_flashStatus(QString status, quint64 id);
  void SI_comReturn(bool ok, quint64 id);
  void SI_WarningMessage(QString message, quint64 id);
  void SI_returnComLog(QString message, quint64 id);
  void SI_flashProgress(double progress, quint64 id);

 private:
  void flashMax(QString memType, quint64 maxSize);
  void flashNow(QString memType, quint64 nowSize);
  int upFile(QString filePath, QString remoteFilePath);
  int downFile(QString remoteFilePath, QString localFilePath);
  int sendCommend(QString sendInfo, QString& reInfo);
  void sshWarrning(QString info) {
    warringInfo = info;
    qWarning() << info;
  };
  int comP(void);
  int comC(bool autoRestart = 0);
  char read_buffer[1024 * 1024 * 4];
  QString warringInfo;
};

#endif // MEMORYEDIT_H
