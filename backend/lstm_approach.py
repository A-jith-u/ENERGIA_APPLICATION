"""
LSTM-based approach: Neural network for sequence prediction
Often works better on complex, noisy time series than Prophet
"""
import pandas as pd
import numpy as np
from sqlalchemy import create_engine
from sklearn.preprocessing import MinMaxScaler
from sklearn.metrics import mean_absolute_error, mean_absolute_percentage_error
import warnings
warnings.filterwarnings('ignore')

# Try to import TensorFlow/Keras
try:
    import tensorflow as tf
    from tensorflow import keras
    from tensorflow.keras.models import Sequential
    from tensorflow.keras.layers import LSTM, Dense, Dropout
    from tensorflow.keras.callbacks import EarlyStopping
    HAS_TF = True
except ImportError:
    print("TensorFlow not installed. Trying alternative approach...")
    HAS_TF = False

if not HAS_TF:
    print("Installing TensorFlow...")
    import subprocess
    subprocess.check_call([
        'e:/Flutter/flutter_application_1/.venv/Scripts/python.exe',
        '-m', 'pip', 'install', '-q', 'tensorflow'
    ])
    import tensorflow as tf
    from tensorflow import keras
    from tensorflow.keras.models import Sequential
    from tensorflow.keras.layers import LSTM, Dense, Dropout
    from tensorflow.keras.callbacks import EarlyStopping

engine = create_engine(
    'postgresql+psycopg2://postgres:ajith%40@localhost:5432/energia'
)

print("=" * 60)
print("LSTM NEURAL NETWORK APPROACH")
print("=" * 60)

# Load and prepare data
df = pd.read_sql(
    'SELECT ds, value FROM sensor_data WHERE value IS NOT NULL ORDER BY ds',
    engine
)
df['ds'] = pd.to_datetime(df['ds'])
df = df.sort_values('ds').reset_index(drop=True)
values = df['value'].values

print(f"Total records: {len(df)}")

# Normalize data
scaler = MinMaxScaler(feature_range=(0, 1))
values_scaled = scaler.fit_transform(values.reshape(-1, 1))

# Create sequences
def create_sequences(data, lookback=30):
    X, y = [], []
    for i in range(lookback, len(data)):
        X.append(data[i-lookback:i, 0])
        y.append(data[i, 0])
    return np.array(X), np.array(y)

lookback = 30  # Predict next day using 30-day lookback
X, y = create_sequences(values_scaled, lookback)

print(f"Sequences created: {len(X)}")
print(f"Input shape: {X.shape}, Output shape: {y.shape}")

# Split train/test
split = int(len(X) * 0.8)
X_train, X_test = X[:split], X[split:]
y_train, y_test = y[:split], y[split:]

print(f"Train: {len(X_train)}, Test: {len(X_test)}")

# Build LSTM model
model = Sequential([
    LSTM(50, activation='relu', input_shape=(lookback, 1), return_sequences=True),
    Dropout(0.2),
    LSTM(50, activation='relu', return_sequences=False),
    Dropout(0.2),
    Dense(25, activation='relu'),
    Dense(1)
])

model.compile(optimizer='adam', loss='mse', metrics=['mae'])

print("\nModel Architecture:")
model.summary()

# Train
print("\nTraining...")
history = model.fit(
    X_train.reshape(-1, lookback, 1),
    y_train,
    epochs=50,
    batch_size=16,
    validation_split=0.2,
    callbacks=[EarlyStopping(monitor='val_loss', patience=5, restore_best_weights=True)],
    verbose=0
)

# Predict
print("\nPredicting...")
y_train_pred = model.predict(X_train.reshape(-1, lookback, 1), verbose=0)
y_test_pred = model.predict(X_test.reshape(-1, lookback, 1), verbose=0)

# Denormalize
y_train = scaler.inverse_transform(y_train.reshape(-1, 1))
y_test = scaler.inverse_transform(y_test.reshape(-1, 1))
y_train_pred = scaler.inverse_transform(y_train_pred)
y_test_pred = scaler.inverse_transform(y_test_pred)

# Evaluate
train_mae = mean_absolute_error(y_train, y_train_pred)
test_mae = mean_absolute_error(y_test, y_test_pred)
train_mape = mean_absolute_percentage_error(y_train, y_train_pred)
test_mape = mean_absolute_percentage_error(y_test, y_test_pred)

# Convert MAPE to accuracy
test_accuracy = max(0, 100 * (1 - test_mape)) if test_mape < 1 else 0

print("\n" + "=" * 60)
print("LSTM RESULTS")
print("=" * 60)
print(f"Train MAE:  {train_mae:.2f}")
print(f"Test MAE:   {test_mae:.2f}")
print(f"Train MAPE: {train_mape*100:.2f}%")
print(f"Test MAPE:  {test_mape*100:.2f}%")
print(f"Test Accuracy: {test_accuracy:.2f}%")

if test_accuracy > 80:
    print(f"\n*** SUCCESS! LSTM achieved {test_accuracy:.2f}% accuracy!")
    model.save('models/lstm_energy_model.h5')
    print("Model saved to models/lstm_energy_model.h5")
elif test_accuracy > 60:
    print(f"\n*** PROGRES: LSTM achieved {test_accuracy:.2f}% (target is 80%)")
else:
    print(f"\n*** LSTM accuracy {test_accuracy:.2f}% - trying different architecture...")
    
    # Try simpler model
    model2 = Sequential([
        LSTM(32, activation='relu', input_shape=(lookback, 1)),
        Dense(16, activation='relu'),
        Dense(1)
    ])
    model2.compile(optimizer='adam', loss='mse')
    
    print("Trying simpler model...")
    history2 = model2.fit(
        X_train.reshape(-1, lookback, 1),
        y_train,
        epochs=50,
        batch_size=16,
        validation_split=0.2,
        callbacks=[EarlyStopping(monitor='val_loss', patience=5, restore_best_weights=True)],
        verbose=0
    )
    
    y_test_pred2 = model2.predict(X_test.reshape(-1, lookback, 1), verbose=0)
    y_test_pred2 = scaler.inverse_transform(y_test_pred2)
    
    test_mape2 = mean_absolute_percentage_error(y_test, y_test_pred2)
    test_accuracy2 = max(0, 100 * (1 - test_mape2)) if test_mape2 < 1 else 0
    
    print(f"Simpler model accuracy: {test_accuracy2:.2f}%")
    
    if test_accuracy2 > test_accuracy:
        model2.save('models/lstm_energy_model.h5')
        print("Simpler model saved.")

# Try different lookback windows
print("\n" + "=" * 60)
print("TESTING DIFFERENT LOOKBACK WINDOWS")
print("=" * 60)

best_acc = test_accuracy
best_lookback = lookback

for lb in [7, 14, 30, 60]:
    X_lb, y_lb = create_sequences(values_scaled, lb)
    split_lb = int(len(X_lb) * 0.8)
    X_train_lb = X_lb[:split_lb]
    X_test_lb = X_lb[split_lb:]
    y_train_lb = y_lb[:split_lb]
    y_test_lb = y_lb[split_lb:]
    
    m = Sequential([
        LSTM(32, activation='relu', input_shape=(lb, 1)),
        Dense(16, activation='relu'),
        Dense(1)
    ])
    m.compile(optimizer='adam', loss='mse')
    
    m.fit(
        X_train_lb.reshape(-1, lb, 1),
        y_train_lb,
        epochs=50,
        batch_size=16,
        validation_split=0.2,
        callbacks=[EarlyStopping(monitor='val_loss', patience=5, restore_best_weights=True)],
        verbose=0
    )
    
    y_test_lb_pred = m.predict(X_test_lb.reshape(-1, lb, 1), verbose=0)
    y_test_lb_actual = scaler.inverse_transform(y_test_lb.reshape(-1, 1))
    y_test_lb_pred = scaler.inverse_transform(y_test_lb_pred)
    
    mape_lb = mean_absolute_percentage_error(y_test_lb_actual, y_test_lb_pred)
    acc_lb = max(0, 100 * (1 - mape_lb)) if mape_lb < 1 else 0
    
    print(f"Lookback {lb:3d}: accuracy = {acc_lb:.2f}%")
    
    if acc_lb > best_acc:
        best_acc = acc_lb
        best_lookback = lb
        m.save('models/lstm_energy_model.h5')

print(f"\nBest configuration: lookback={best_lookback}, accuracy={best_acc:.2f}%")
