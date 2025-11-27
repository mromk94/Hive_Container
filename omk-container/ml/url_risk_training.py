"""Offline training pipeline for URL risk classifier.

This script is NOT used on-device. It prepares data from labeled feeds,
engineers features, trains a small neural classifier, and exports a quantized
TFLite model suitable for mobile.

Usage (example):

    python url_risk_training.py \
        --input data/url_risk_labeled.csv \
        --output_model models/url_risk.tflite

The input CSV is expected to follow the schema described in
../docs/URL-RISK-FEATURES-SPEC.md.
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
import pandas as pd
import tensorflow as tf


FEATURE_COLUMNS = [
    "domain_age_days",
    "cert_valid_days",
    "redirect_count",
    "path_entropy",
    "host_entropy",
    "domain_edit_distance",
    "asn_reputation_score",
    "page_text_entropy",
]


def shannon_entropy(text: str) -> float:
    if not text:
        return 0.0
    # Simple byte-level entropy
    data = text.encode("utf-8", errors="ignore")
    if not data:
        return 0.0
    counts = np.bincount(np.frombuffer(data, dtype=np.uint8), minlength=256)
    probs = counts[counts > 0] / len(data)
    return float(-(probs * np.log2(probs)).sum())


def engineer_features(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    # Domain age
    if {"domain_created_at", "observed_at"}.issubset(df.columns):
        created = pd.to_datetime(df["domain_created_at"], errors="coerce")
        observed = pd.to_datetime(df["observed_at"], errors="coerce")
        age = (observed - created).dt.total_seconds() / (24 * 3600)
        df["domain_age_days"] = age.clip(lower=0).fillna(0)

    # Cert valid days
    if {"cert_not_before", "cert_not_after"}.issubset(df.columns):
        not_before = pd.to_datetime(df["cert_not_before"], errors="coerce")
        not_after = pd.to_datetime(df["cert_not_after"], errors="coerce")
        valid_days = (not_after - not_before).dt.total_seconds() / (24 * 3600)
        df["cert_valid_days"] = valid_days.clip(lower=0).fillna(0)

    # Entropies
    if "path" in df.columns:
        df["path_entropy"] = df["path"].fillna("").astype(str).map(shannon_entropy)
    if "host" in df.columns:
        df["host_entropy"] = df["host"].fillna("").astype(str).map(shannon_entropy)

    # Page text entropy
    if "page_text" in df.columns:
        df["page_text_entropy"] = df["page_text"].fillna("").astype(str).map(
            shannon_entropy
        )

    # domain_edit_distance and asn_reputation_score are expected as numeric
    # columns if available. Otherwise default to 0.
    for col in ["domain_edit_distance", "asn_reputation_score"]:
        if col not in df.columns:
            df[col] = 0.0

    return df


def load_and_prepare(path: Path) -> tuple[np.ndarray, np.ndarray]:
    df = pd.read_csv(path)
    df = engineer_features(df)

    missing = [c for c in FEATURE_COLUMNS if c not in df.columns]
    if missing:
        raise SystemExit(f"Missing feature columns: {missing}")

    X = df[FEATURE_COLUMNS].astype("float32").to_numpy()
    y = df["label"].astype("int64").to_numpy()

    # Optional: collapse label 2 -> 1 for binary classification
    y = np.where(y >= 1, 1, 0)

    # Train/valid split
    n = len(X)
    idx = np.arange(n)
    np.random.shuffle(idx)
    split = int(n * 0.8)
    train_idx, val_idx = idx[:split], idx[split:]
    return (X[train_idx], y[train_idx]), (X[val_idx], y[val_idx])


def build_model(input_dim: int) -> tf.keras.Model:
    inputs = tf.keras.Input(shape=(input_dim,), dtype="float32")
    x = tf.keras.layers.Normalization()(inputs)
    x = tf.keras.layers.Dense(32, activation="relu")(x)
    x = tf.keras.layers.Dense(16, activation="relu")(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid")(x)
    model = tf.keras.Model(inputs=inputs, outputs=outputs)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-3),
        loss="binary_crossentropy",
        metrics=["accuracy"],
    )
    return model


def train_and_export(input_csv: Path, output_model: Path) -> None:
    (X_train, y_train), (X_val, y_val) = load_and_prepare(input_csv)

    model = build_model(X_train.shape[1])
    model.fit(
        X_train,
        y_train,
        validation_data=(X_val, y_val),
        epochs=10,
        batch_size=256,
        verbose=2,
    )

    # Convert to TFLite with dynamic range quantization
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    output_model.parent.mkdir(parents=True, exist_ok=True)
    output_model.write_bytes(tflite_model)
    print(f"Exported quantized TFLite model to {output_model}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output_model", type=Path, required=True)
    args = parser.parse_args()

    train_and_export(args.input, args.output_model)


if __name__ == "__main__":
    main()
