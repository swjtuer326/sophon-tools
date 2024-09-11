#ifndef TABLEDELEGATES_H
#define TABLEDELEGATES_H

#include "mainwindow.h"

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
  QRegularExpressionValidator userPasswdValidator =
    QRegularExpressionValidator(QRegularExpression("^[a-zA-Z0-9_]*$"), this);
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
      lineEdit->setText(value.trimmed());
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

#endif // TABLEDELEGATES_H
