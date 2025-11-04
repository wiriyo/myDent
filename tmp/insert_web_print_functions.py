from pathlib import Path
import re

path = Path(r"lib/features/printing/render/printer_settings_page.dart")
text = path.read_text(encoding="utf-8")

pattern = re.compile(r"  Future<void> _print\(\) async \{[\s\S]*?\n  \}")
match = pattern.search(text)
if not match:
    raise SystemExit('print block not found')
insert_pos = match.end()

new_functions = """

  Future<void> _printWeb() async {
    if (!_qzService.isEnabled) {
      await _printWithBrowser(forceRecapture: true);
      return;
    }
    if (!mounted) return;
    setState(() => _busyCapture = true);
    var releaseBusy = true;
    try {
      QzStatusSnapshot status = _qzService.statusNotifier.value;
      if (!status.isReady) {
        try {
          await _qzService.ensureReady();
        } on QzPrintException catch (error) {
          _showQzErrorSnackBar(error);
        } catch (error) {
          if (mounted) {
            _showSnackBarSafe(
              SnackBar(content: Text('????????? QZ Tray ?????????: $error')),
            );
          }
        }
        status = _qzService.statusNotifier.value;
      }
      if (status.isReady) {
        if (mounted) setState(() => _busyCapture = false);
        releaseBusy = false;
        await _printWithQz(forceRecapture: true);
        return;
      }
      if (!mounted) return;
      _showSnackBarSafe(
        const SnackBar(
          content: Text(
            'QZ Tray ????????????????? ????????????????????????????????????????????',
          ),
        ),
      );
    } finally {
      if (releaseBusy && mounted) {
        setState(() => _busyCapture = false);
      }
    }
  }

  Future<void> _printWithBrowser({bool forceRecapture = false}) async {
    if (_busyCapture) return;
    setState(() => _busyCapture = true);
    try {
      if (_browserMode == BrowserPrintMode.png) {
        final png = await _ensurePng(forceRecapture: forceRecapture);
        if (!mounted) return;
        if (png == null) {
          _showSnackBarSafe(
            const SnackBar(content: Text('????????????????????????????????')),
          );
          return;
        }
        final String base64 = _cachedPngBase64 ?? base64Encode(png);
        await BrowserPrintService.I.printPng(
          base64,
          pixelWidth: _browserPixelWidth,
          autoClose: _browserAutoClose,
        );
      } else {
        final receipt = _sampleReceiptData();
        final appointment = _sampleAppointmentData();
        final slip = AppointmentSlipModel(
          clinic: receipt.clinic,
          patient: receipt.patient,
          appointment: appointment,
        );
        final payload = BrowserPrintPayloadBuilder.combined(
          receipt: receipt,
          slip: slip,
          clinicName: _clinicName,
          clinicAddress: _clinicAddress,
          clinicPhone: _clinicPhone,
          clinicTaxId: _clinicTaxId,
          clinicLineId: _clinicLineId,
          headerSpace: _printingHeaderSpace,
          pixelWidth: _browserPixelWidth,
          logoBytes: _logo,
        );
        await BrowserPrintService.I.printHtml(
          payload,
          autoClose: _browserAutoClose,
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackBarSafe(
        SnackBar(content: Text('???????????????????????????: $error')),
      );
    } finally {
      if (mounted) setState(() => _busyCapture = false);
    }
  }

  Future<void> _printWithQz({bool forceRecapture = false}) async {
    if (_busyCapture) return;
    if (!_qzService.isEnabled) {
      _showSnackBarSafe(
        const SnackBar(content: Text('QZ Tray ??????????????????????????')),
      );
      return;
    }

    setState(() => _busyCapture = true);

    try {
      final png = await _ensurePng(forceRecapture: forceRecapture);
      if (!mounted) return;
      if (png == null) {
        _showSnackBarSafe(
          const SnackBar(content: Text('????????????????????????????????')),
        );
        return;
      }
      await _performQzPrint(png);
    } on QzPrintException catch (error) {
      await _handleQzException(error);
    } catch (error) {
      if (!mounted) return;
      _showSnackBarSafe(
        SnackBar(content: Text('????????? QZ Tray ???????: $error')),
      );
    } finally {
      if (mounted) setState(() => _busyCapture = false);
    }
  }

  Future<void> _performQzPrint(Uint8List png) async {
    await _qzService.ensureReady();
    if (!mounted) return;
    try {
      await _qzService.ensureSecurityReady();
    } on QzPrintException catch (error) {
      final QzStatusSnapshot? snapshot =
          error.original is QzStatusSnapshot
              ? error.original as QzStatusSnapshot
              : null;
      await _showQzSecurityDialog(error, snapshot);
      return;
    }
    final List<String> printers = await _qzService.listPrinters();
    if (!mounted) return;
    String? printer = _savedQzPrinter;

    if (printer != null && !printers.contains(printer)) {
      await _qzService.savePrinter(null);
      printer = null;
      if (mounted) {
        setState(() => _savedQzPrinter = null);
        _showSnackBarSafe(
          const SnackBar(
            content: Text('??????????????????????????? QZ Tray ???? ??????????????'),
          ),
        );
      }
    }

    if (printer == null) {
      final choice = await _pickPrinter(printers);
      if (!mounted) return;
      if (choice == null) {
        return;
      }
      printer = choice.printerName;
      if (choice.remember && printer != null) {
        await _qzService.savePrinter(printer);
        if (mounted) setState(() => _savedQzPrinter = printer);
      } else {
        await _qzService.savePrinter(null);
        if (mounted) setState(() => _savedQzPrinter = null);
      }
    }

    final int feedLines = PrintSettings.feedLinesFromSetting(_printingPostFeed);
    final result = await _qzService.printPng(
      png,
      printerName: printer,
      postFeed: feedLines,
    );
    final String? used = result.printerName ?? printer;
    if (used != null && used.isNotEmpty) {
      await _qzService.savePrinter(used);
      if (mounted) setState(() => _savedQzPrinter = used);
    }

    if (mounted) {
      _showSnackBarSafe(
        const SnackBar(content: Text('????????? QZ Tray ?????????????')),
      );
    }
  }

  Future<void> _handleQzException(QzPrintException error) async {
    if (!mounted) return;
    if (error.code == 'qz_printer_not_found') {
      await _handlePrinterNotFound(error);
      return;
    }
    _showQzErrorSnackBar(error);
  }

  Future<void> _handlePrinterNotFound(QzPrintException error) async {
    if (!mounted) return;
    await _qzService.savePrinter(null);
    if (mounted) {
      setState(() => _savedQzPrinter = null);
    }
    _hideCurrentSnackBarSafe();
    _showSnackBarSafe(SnackBar(content: Text(error.message)));
    try {
      final List<String> printers = await _qzService.listPrinters();
      if (!mounted || printers.isEmpty) {
        return;
      }
      final _PrinterChoice? choice = await _pickPrinter(printers);
      if (!mounted || choice == null) {
        return;
      }
      await _qzService.savePrinter(
        choice.remember ? choice.printerName : null,
      );
      if (choice.remember && choice.printerName != null && mounted) {
        setState(() => _savedQzPrinter = choice.printerName);
      }
      _hideCurrentSnackBarSafe();
      await _printWithQz();
    } catch (e) {
      if (!mounted) return;
      _showSnackBarSafe(
        SnackBar(content: Text('?????????????????????????????????? QZ Tray: $e')),
      );
    }
  }

  void _showQzErrorSnackBar(QzPrintException error) {
    if (!mounted) return;
    _hideCurrentSnackBarSafe();
    _showSnackBarSafe(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error.message),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: () {
                    _hideCurrentSnackBarSafe();
                    _printWithQz();
                  },
                  child: const Text('???????????'),
                ),
                TextButton(
                  onPressed: () {
                    _hideCurrentSnackBarSafe();
                    _runQzSelfTestFromSettings();
                  },
                  child: const Text('Self-test (QZ Tray)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQzSecurityDialog(
    QzPrintException error,
    QzStatusSnapshot? status,
  ) async {
    if (!mounted) return;
    final bool certificateInvalid = status?.hasCertificateIssue ?? false;
    final bool whitelistOk = status?.isWhitelisted ?? false;
    final String subject = status?.certificateSubject ?? '-';
    final String issuer = status?.certificateIssuer ?? '-';
    final String? expiresAt =
        status?.certificateExpiresAt?.toLocal().toString();

    final List<Widget> contentWidgets = [
      Text(
        certificateInvalid
            ? '??????????? QZ Tray ???????????????? ????????????????????'
            : 'QZ Tray ??????????????????????????????? (Untrusted website)',
      ),
      const SizedBox(height: 12),
      Text('Subject: $subject'),
      Text('Issuer: $issuer'),
    ];
    if (expiresAt != null) {
      contentWidgets.addAll([
        const SizedBox(height: 8),
        Text('???????: $expiresAt'),
      ]);
    }
    contentWidgets.addAll([
      const SizedBox(height: 12),
      Text(
        whitelistOk
            ? '?? whitelist ???????? ??????????? QZ Tray ??????????????????????'
            : '???????? whitelist ?????????? localhost/127.0.0.1 ?? whitelist.txt ???????? Site Manager',
      ),
    ]);

    final bool? action = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('QZ Tray ??????????????'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contentWidgets,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('???'),
            ),
            TextButton(
              onPressed: () async {
                await _qzService.ensureWhitelist();
                if (!mounted) return;
                _showSnackBarSafe(
                  const SnackBar(
                    content: Text('????? host ???? whitelist ????'),
                  ),
                );
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('????????? whitelist'),
            ),
            TextButton(
              onPressed: () async {
                final bool opened = await _qzService.openSiteManager();
                if (!mounted) return;
                if (!opened) {
                  _showSnackBarSafe(
                    const SnackBar(
                      content: Text('????????????? QZ Tray Site Manager ???'),
                    ),
                  );
                }
                Navigator.of(dialogContext).pop(opened);
              },
              child: const Text('???? Site Manager'),
            ),
          ],
        );
      },
    );

    if (action == true && certificateInvalid && mounted) {
      _showSnackBarSafe(
        const SnackBar(
          content: Text(
            '????????????????????????????? qz.io/latest-signing ????????????? QZ Tray',
          ),
        ),
      );
    }
  }

  Future<_PrinterChoice?> _pickPrinter(List<String> printers) async {
    if (!mounted) return null;
    if (printers.isEmpty) {
      _showSnackBarSafe(
        const SnackBar(content: Text('QZ Tray ???????????????????????????????')),
      );
      return null;
    }

    String? current = _savedQzPrinter;
    if (current != null && !printers.contains(current)) {
      current = null;
    }
    current ??= printers.isNotEmpty ? printers.first : null;
    bool remember = current != null;

    return showDialog<_PrinterChoice>(
      context: context,
      builder: (dialogContext) {
        String? selection = current;
        bool rememberSelection = remember;
        final double listHeight = (printers.length * 56.0).clamp(160.0, 320.0);

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('????????????????? QZ Tray'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: listHeight,
                    width: 360,
                    child: RadioGroup<String?>(
                      groupValue: selection,
                      onChanged: (value) {
                        setStateDialog(() {
                          selection = value;
                          if (value == null) {
                            rememberSelection = false;
                          }
                        });
                      },
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final printerName in printers)
                            RadioListTile<String?>(
                              title: Text(printerName),
                              value: printerName,
                            ),
                          RadioListTile<String?>(
                            title: const Text('???????????'),
                            value: null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    title: const Text('????????????????????'),
                    value: rememberSelection,
                    onChanged:
                        selection == null
                            ? null
                            : (value) {
                                setStateDialog(() {
                                  rememberSelection = value ?? false;
                                });
                              },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('??????'),
                ),
                FilledButton(
                  onPressed:
                      selection == null && rememberSelection
                          ? null
                          : () {
                              Navigator.of(context).pop(
                                _PrinterChoice(
                                  printerName: selection,
                                  remember:
                                      rememberSelection && selection != null,
                                ),
                              );
                            },
                  child: const Text('????'),
                ),
              ],
            );
          },
        );
      },
    );
  }
"""

text = text[:insert_pos] + new_functions + text[insert_pos:]
path.write_text(text, encoding="utf-8")
