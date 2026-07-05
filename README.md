# Aul2AudioFilter

AviUtl ExEdit2 用の音声フィルタープラグインです。

プラグイン上の表示名は「サウンドエフェクター」です。エコー、リバーブ、コーラスなどの音声エフェクトを追加していくための土台として開発します。

## 配置

- `Aul2AudioFilter.dpr` / `Aul2AudioFilter.dproj`: Delphi プロジェクト本体
- `Aul2AudioFilterPlugin.pas`: プラグインのフィルターテーブルと音声処理
- `Lib`: 共通ライブラリ
- `Sample`: 動作確認用 WAV ファイル
- `Win64`: Debug / Release の中間出力

## 出力

ビルド後、AviUtl2 のプラグインフォルダへ `.auf2` として出力します。

```text
C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioFilter.auf2
```

開発ルールやビルド方法は [note.md](note.md) を参照してください。
