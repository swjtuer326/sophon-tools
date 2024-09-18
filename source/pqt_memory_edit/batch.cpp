#include "batch.h"
#include "ui_batch.h"

class portSpinBoxDelegate : public QStyledItemDelegate {
 public:
  portSpinBoxDelegate(QObject* parent = 0):
    QStyledItemDelegate(parent) {};
  QWidget* createEditor(QWidget* parent, const QStyleOptionViewItem& option,
    const QModelIndex& index) const override {
    Q_UNUSED(option);
    Q_UNUSED(index);
    QSpinBox* editor = new QSpinBox(parent);
    editor->setRange(22, 65535);
    editor->setValue(22);
    return editor;
  };
  void setEditorData(QWidget* editor,
    const QModelIndex& index) const override {
    int value = index.model()->data(index, Qt::EditRole).toInt();
    QSpinBox* spinBox = static_cast<QSpinBox*>(editor);
    spinBox->setValue(value);
    spinBox->interpretText();
  };
  void setModelData(QWidget* editor, QAbstractItemModel* model,
    const QModelIndex& index) const override {
    QSpinBox* spinBox = static_cast<QSpinBox*>(editor);
    spinBox->interpretText();
    int value = spinBox->value();
    model->setData(index, value, Qt::EditRole);
  };
  void updateEditorGeometry(QWidget* editor,
    const QStyleOptionViewItem& option, const QModelIndex&) const override {
    editor->setGeometry(option.rect);
  };
};

class infLineEditDelegate : public QStyledItemDelegate {
 public:
  QRegularExpressionValidator userPasswdValidator =
    QRegularExpressionValidator(QRegularExpression("^[ -~]*$"), this);
  infLineEditDelegate(QObject* parent = 0):
    QStyledItemDelegate(parent) {};
  QWidget* createEditor(QWidget* parent, const QStyleOptionViewItem& option,
    const QModelIndex& index) const override {
    Q_UNUSED(option);
    Q_UNUSED(index);
    QLineEdit* editor = new QLineEdit(parent);
    editor->setValidator(&userPasswdValidator);
    return editor;
  };
  void setEditorData(QWidget* editor,
    const QModelIndex& index) const override {
    QString value = index.model()->data(index, Qt::EditRole).toString();
    QLineEdit* lineEdit = static_cast<QLineEdit*>(editor);
    lineEdit->setText(value);
  };
  void setModelData(QWidget* editor, QAbstractItemModel* model,
    const QModelIndex& index) const override {
    QLineEdit* lineEdit = static_cast<QLineEdit*>(editor);
    QString value = lineEdit->text();
    model->setData(index, value, Qt::EditRole);
  };
  void updateEditorGeometry(QWidget* editor,
    const QStyleOptionViewItem& option, const QModelIndex&) const override {
    editor->setGeometry(option.rect);
  };
};

class ipLineEditDelegate : public QStyledItemDelegate {
 public:
  QRegularExpression
  regex = QRegularExpression("^((\\d{1,2}|1\\d{2}|2[0-4]\\d|25[0-5])\\.){3}(\\d{1,2}|1\\d{2}|2[0-4]\\d|25[0-5])$");
  ipLineEditDelegate(QObject* parent = 0): QStyledItemDelegate(parent) {};
  QWidget* createEditor(QWidget* parent, const QStyleOptionViewItem& option,
    const QModelIndex& index) const override {
    Q_UNUSED(option);
    Q_UNUSED(index);
    QLineEdit* editor = new QLineEdit(parent);
    return editor;
  };
  void setEditorData(QWidget* editor,
    const QModelIndex& index) const override {
    QString value = index.model()->data(index, Qt::EditRole).toString();
    QLineEdit* lineEdit = static_cast<QLineEdit*>(editor);
    QRegularExpressionMatch match = regex.match(value);
    if (match.hasMatch())
      lineEdit->setText(value);
    else
      lineEdit->setText("0.0.0.0");
    qDebug() << "setEditorData value " << value;
  };
  void setModelData(QWidget* editor, QAbstractItemModel* model,
    const QModelIndex& index)
  const override {
    QLineEdit* lineEdit = static_cast<QLineEdit*>(editor);
    QString value = lineEdit->text();
    QRegularExpressionMatch match = regex.match(value);
    if (match.hasMatch())
      value = value;
    else
      value = QString("0.0.0.0");
    qDebug() << "setEditorData value " << value;
    model->setData(index, value, Qt::EditRole);
  };
  void updateEditorGeometry(QWidget* editor,
    const QStyleOptionViewItem& option, const QModelIndex&) const override {
    editor->setGeometry(option.rect);
  };
};

Batch::Batch(MemoryEdit::memInfoStruct& inMemInfo, QDir inLocalDir,
  remoteInfStruct* pRemoteInfStruct, QWidget* parent) :
  QDialog(parent),
  ui(new Ui::Batch) {
  ui->setupUi(this);
  ui->tableWidget->setHorizontalHeaderLabels({"IPv4地址", "SSH端口", "用户名", "密码", "标记", "执行状态"});
  ui->tableWidget->setItemDelegateForColumn(0,
    new ipLineEditDelegate(this));
  ui->tableWidget->setItemDelegateForColumn(1,
    new portSpinBoxDelegate(this));
  ui->tableWidget->setItemDelegateForColumn(2,
    new infLineEditDelegate(this));
  ui->tableWidget->setItemDelegateForColumn(3,
    new infLineEditDelegate(this));
  ui->tableWidget->setRowCount(1);
  ui->tableWidget->setSelectionBehavior(QAbstractItemView::SelectRows);
  if (pRemoteInfStruct != nullptr) {
    defaultRemoteInfStruct.ip = pRemoteInfStruct->ip;
    defaultRemoteInfStruct.port = pRemoteInfStruct->port;
    defaultRemoteInfStruct.user = pRemoteInfStruct->user;
    defaultRemoteInfStruct.passwd = pRemoteInfStruct->passwd;
  }
  ui->tableWidget->horizontalHeader()->setStretchLastSection(true);
  ui->tableWidget->setWordWrap(true);
  ui->tableWidget->setItem(0, 0, new QTableWidgetItem(defaultRemoteInfStruct.ip));
  ui->tableWidget->setItem(0, 1,
    new QTableWidgetItem(QString::number(defaultRemoteInfStruct.port)));
  ui->tableWidget->setItem(0, 2,
    new QTableWidgetItem(defaultRemoteInfStruct.user));
  ui->tableWidget->setItem(0, 3,
    new QTableWidgetItem(defaultRemoteInfStruct.passwd));
  ui->tableWidget->setItem(0, 4, new QTableWidgetItem());
  ui->tableWidget->item(0, 4)->setCheckState(Qt::Checked);
  ui->tableWidget->resizeColumnsToContents();
  ui->tableWidget->horizontalHeader()->setSectionResizeMode(
    ui->tableWidget->columnCount() - 1, QHeaderView::Stretch);
  connect(ui->tableWidget,
  &QTableWidget::itemChanged, this, [this](QTableWidgetItem * item) {
    this->ui->tableWidget->resizeColumnsToContents();
    ui->tableWidget->horizontalHeader()->setSectionResizeMode(
      ui->tableWidget->columnCount() - 1, QHeaderView::Stretch);
  });
  memInfo = inMemInfo;
  localDir = inLocalDir;
  QDir directory("://batchConf");
  QFileInfoList fileList = directory.entryInfoList(QDir::Files |
      QDir::NoDotAndDotDot);
  for (const QFileInfo& fileInfo : fileList) {
    QString fileName = fileInfo.fileName();
    ui->comboBox->addItem(fileName);
  }
  flashTableWidget(ui->tableWidget);
  connect(ui->tableWidget, &QTableWidget::cellChanged, [&](int row, int column) {
    QTableWidgetItem* item = ui->tableWidget->item(row, column);
    if (column == 4)
      flashTableWidget(ui->tableWidget);
  });
  QObject::connect(ui->comboBox,
    QOverload<const QString&>::of(&QComboBox::activated), [ = ](
  const QString & text) {
    QString filePath = "://batchConf/" + text;
    qDebug() << "Load preset configuration file: " << text;
    if (!filePath.isEmpty())
      readTableDataFromJson(ui->tableWidget, filePath);
  });
}

Batch::~Batch() {
  delete ui;
}

void Batch::on_pushButton_5_clicked() {
  int selectedRow = ui->tableWidget->currentRow();
  if (selectedRow >= 0) {
    ui->tableWidget->insertRow(selectedRow + 1);
    for (int col = 0; col < 5; ++col) {
      QTableWidgetItem* item = ui->tableWidget->item(selectedRow, col);
      QTableWidgetItem* newItem = new QTableWidgetItem(*item);
      ui->tableWidget->setItem(selectedRow + 1, col, newItem);
    }
  }
}


void Batch::on_pushButton_6_clicked() {
  int selectedRow = ui->tableWidget->currentRow();
  int rowNum = ui->tableWidget->rowCount();
  if ((selectedRow >= 0) && (rowNum > 1))
    ui->tableWidget->removeRow(selectedRow);
}

void Batch::writeTableDataToJson(const QTableWidget* tableWidget,
  const QString& filePath) {
  QJsonArray jsonArray;
  for (int row = 0; row < tableWidget->rowCount(); ++row) {
    for (int col = 0; col < 4; ++col) {
      if (tableWidget->item(row, col) == NULL) {
        QMessageBox::warning(this, "警告", "表格中有空行");
        return;
      }
    }
  }
  for (int row = 0; row < tableWidget->rowCount(); ++row) {
    QJsonObject jsonObject;
    jsonObject["IP"] = tableWidget->item(row, 0)->text();
    jsonObject["Port"] = tableWidget->item(row, 1)->text().toInt();
    jsonObject["Username"] = tableWidget->item(row, 2)->text();
    jsonObject["Password"] = tableWidget->item(row, 3)->text();
    jsonArray.append(jsonObject);
  }
  QJsonObject finalObject;
  finalObject["remoteInf"] = jsonArray;
  QJsonDocument jsonDoc(finalObject);
  QFile file(filePath);
  if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
    file.write(jsonDoc.toJson());
    file.close();
    qDebug() << "Table data written to" << filePath;
  }
  else
    qWarning() << "Failed to open file for writing:" << file.errorString();
}
void Batch::flashTableWidget(const QTableWidget* tableWidget) {
  for (int row = 0; row < tableWidget->rowCount(); ++row) {
    for (int col = 0; col < tableWidget->columnCount(); ++col) {
      if (col == 4) {
        QString Clstr = QString((tableWidget->item(row,
                col)->checkState() == Qt::Checked) ? "执行" : "跳过");
        tableWidget->item(row, col)->setText(Clstr);
      }
    }
  }
}
void Batch::readTableDataFromJson(QTableWidget* tableWidget,
  const QString& filePath) {
  QFile file(filePath);
  tableWidget->blockSignals(true);
  if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
    QByteArray jsonData = file.readAll();
    file.close();
    QJsonDocument jsonDoc = QJsonDocument::fromJson(jsonData);
    if (jsonDoc.isObject()) {
      QJsonObject jsonObject = jsonDoc.object();
      if (jsonObject.contains("remoteInf") && jsonObject["remoteInf"].isArray()) {
        QJsonArray jsonArray = jsonObject["remoteInf"].toArray();
        tableWidget->clearContents();
        tableWidget->setRowCount(jsonArray.size());
        for (int row = 0; row < jsonArray.size(); ++row) {
          QJsonObject remoteInfo = jsonArray[row].toObject();
          tableWidget->setItem(row, 0, new QTableWidgetItem(remoteInfo["IP"].toString()));
          tableWidget->setItem(row, 1,
            new QTableWidgetItem(QString::number(remoteInfo["Port"].toInt())));
          tableWidget->setItem(row, 2,
            new QTableWidgetItem(remoteInfo["Username"].toString()));
          tableWidget->setItem(row, 3,
            new QTableWidgetItem(remoteInfo["Password"].toString()));
          tableWidget->setItem(row, 4, new QTableWidgetItem("执行"));
          tableWidget->item(row, 4)->setCheckState(Qt::Checked);
        }
        qDebug() << "Table data read from" << filePath;
      }
    }
    else
      QMessageBox::warning(this, "警告", "Invalid JSON data in file");
  }
  else
    QMessageBox::warning(this, "警告",
      "Failed to open file for reading:" + file.errorString().toLocal8Bit());
  tableWidget->blockSignals(false);
}
void Batch::on_pushButton_2_clicked() {
  QString saveFilePath = QFileDialog::getSaveFileName(nullptr, "Save JSON File",
      QDir::homePath(), "JSON Files (*.json)");
  if (!saveFilePath.isEmpty())
    writeTableDataToJson(ui->tableWidget, saveFilePath);
}
void Batch::on_pushButton_clicked() {
  QString openFilePath = QFileDialog::getOpenFileName(nullptr, "Open JSON File",
      QDir::homePath(), "JSON Files (*.json)");
  if (!openFilePath.isEmpty())
    readTableDataFromJson(ui->tableWidget, openFilePath);
}
void Batch::on_pushButton_3_clicked() {
  remoteNum = ui->tableWidget->rowCount();
  closeNum = 0;
  startNum = 0;
  QString changeInf =
    QString("内存将修改为NPU:%1MiB VPU:%2MiB VPP:%3MiB\n配置目标如下：\n").arg(
      memInfo.npu_mem).arg(memInfo.vpu_mem).arg(memInfo.vpp_mem);
  for (int row = 0; row < remoteNum; ++row) {
    changeColorTableRow(ui->tableWidget, row, noneColor);
    if (ui->tableWidget->item(row, 4)->checkState() == Qt::Unchecked)
      continue;
    for (int column = 0; column < 4; ++column) {
      if (ui->tableWidget->item(row, column) == NULL) {
        QMessageBox::warning(this, "警告", "表格中有空行");
        return;
      }
      changeInf += " ";
      changeInf += ui->tableWidget->item(row, column)->text();
    }
    changeInf += "\n";
  }
  QMessageBox::StandardButton reply;
  reply = QMessageBox::question(nullptr, "请确认配置是否正确",
      changeInf, QMessageBox::Yes | QMessageBox::No);
  if (reply == QMessageBox::No)
    return;
  enableEdit(false);
  startBatch();
}
void
Batch::flashInfo(MemoryEdit::memInfoStruct* max,
  MemoryEdit::memInfoStruct* now) {
  qDebug() << "flashInfo get info";
}
void
Batch::flashStatus(QString status, quint64 id) {
  qDebug() << "flashStatus " << "[" << id + 1 << "] " << status;
  ui->tableWidget->setItem(id, ui->tableWidget->columnCount() - 1,
    new QTableWidgetItem(status));
}
void
Batch::comReturn(bool ok, quint64 id) {
  closeNum += 1;
  if (ui->tableWidget->item(id, ui->tableWidget->columnCount() - 1) == NULL)
    return;
  QString tempText;
  tempText += ok ? "OK|" : "Error|";
  tempText +=  ui->tableWidget->item(id,
      ui->tableWidget->columnCount() - 1)->text();
  ui->tableWidget->item(id,
    ui->tableWidget->columnCount() - 1)->setText(tempText);
  changeColorTableRow(ui->tableWidget, id, ok ? sucessColor : errorColor);
  if (closeNum == remoteNum)
    enableEdit(true);
  startBatch();
}
void
Batch::WarningMessage(QString message, quint64 id) {
  if (!(message.contains("error", Qt::CaseInsensitive) ||
      message.contains("warning", Qt::CaseInsensitive)))
    flashStatus(message, id);
  QMessageBox::warning(this, "警告",
    QString("[%1] %2").arg(id + 1).arg(message));
}
void
Batch::returnComLog(QString message, quint64 id) {
  qDebug() << "returnComLog " << "[" << id + 1 << "] " << message;
}
void
Batch::enableEdit(bool enable) {
  ui->pushButton_2->setEnabled(enable);
  ui->pushButton_3->setEnabled(enable);
  ui->pushButton_4->setEnabled(enable);
  ui->pushButton_5->setEnabled(enable);
  ui->pushButton_6->setEnabled(enable);
  ui->pushButton_7->setEnabled(enable);
  ui->pushButton_8->setEnabled(enable);
  ui->pushButton->setEnabled(enable);
  ui->tableWidget->setEnabled(enable);
  ui->comboBox->setEnabled(enable);
}
void
Batch::flashProgress(double progress, quint64 id) {
  if (ui->tableWidget->item(id, ui->tableWidget->columnCount() - 1) == NULL)
    return;
  QStringList tempStrList = ui->tableWidget->item(id,
      ui->tableWidget->columnCount() - 1)->text().split("|");
  QString tempText = QString::number(progress * 100, 'd',
      2) + "%" + "|" + tempStrList.at(tempStrList.size() > 1 ? 1 : 0);
  ui->tableWidget->item(id,
    ui->tableWidget->columnCount() - 1)->setText(tempText);
}
void Batch::on_pushButton_4_clicked() {
  this->close();
}
void Batch::on_pushButton_7_clicked() {
  for (int row = 0; row < ui->tableWidget->rowCount(); ++row)
    ui->tableWidget->item(row, 4)->setCheckState(Qt::Checked);
}

void Batch::on_pushButton_8_clicked() {
  for (int row = 0; row < ui->tableWidget->rowCount(); ++row)
    ui->tableWidget->item(row, 4)->setCheckState(Qt::Unchecked);
}

void Batch::changeColorTableRow(QTableWidget* tableWidget, quint64 row,
  QColor color) {
  for (int col = 0; col < tableWidget->columnCount(); ++col) {
    QTableWidgetItem* item = tableWidget->item(row, col);
    if (item)
      item->setBackground(QBrush(color));
  }
}

void Batch::startBatch() {
  if (startNum == remoteNum)
    return;
  if ((startNum - closeNum) < ui->comboBoxMaxBatch->currentText().toUInt()) {
    qint64 maxBatch = startNum + ((ui->comboBoxMaxBatch->currentText().toUInt()
          - (startNum - closeNum)));
    maxBatch = maxBatch > remoteNum ? remoteNum : maxBatch;
    for (; startNum < maxBatch; startNum += 1) {
      if (ui->tableWidget->item(startNum, 4)->checkState() == Qt::Unchecked) {
        closeNum += 1;
        maxBatch = maxBatch + 1 > remoteNum ? remoteNum : maxBatch + 1;
        continue;
      }
      MemoryEdit* pMemoryEdit = new MemoryEdit(this);
      pMemoryEdit->memSet = memInfo;
      pMemoryEdit->setLoginInfo(ui->tableWidget->item(startNum, 0)->text(),
        ui->tableWidget->item(startNum, 1)->text().toInt(),
        ui->tableWidget->item(startNum, 2)->text(),
        ui->tableWidget->item(startNum, 3)->text(),
        localDir,
        1,
        startNum,
        true);
      pMemoryEdit->start();
      changeColorTableRow(ui->tableWidget, startNum, runningColor);
    }
  }
}
