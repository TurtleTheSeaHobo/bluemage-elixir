defmodule Bluemage.Ahrs do
  def update(gx, gy, gz, ax, ay, az, mx, my, mz, period, %Bluemage.Quaternion{} = quat) do
    beta = 1.0   
    q1x2 = 2.0 * quat.q1
    q2x2 = 2.0 * quat.q2
    q3x2 = 2.0 * quat.q3
    q4x2 = 2.0 * quat.q4
    q1q3x2 = 2.0 * quat.q1 * quat.q3
    q3q4x2 = 2.0 * quat.q3 * quat.q4
    q1q1 = quat.q1 * quat.q1
    q1q2 = quat.q1 * quat.q2
    q1q3 = quat.q1 * quat.q3
    q1q4 = quat.q1 * quat.q4
    q2q2 = quat.q2 * quat.q2
    q2q3 = quat.q2 * quat.q3
    q2q4 = quat.q2 * quat.q4
    q3q3 = quat.q3 * quat.q3
    q3q4 = quat.q3 * quat.q4
    q4q4 = quat.q4 * quat.q4

    # Normalise accelerometer measurement
    norm = :math.sqrt(ax * ax + ay * ay + az * az)
    
    norm = 1 / norm
    ax = ax * norm
    ay = ay * norm
    az = az * norm

    # Normalise magnetometer measurement
    norm = :math.sqrt(mx * mx + my * my + mz * mz)
    norm = 1 / norm
    mx = mx * norm;
    my = my * norm;
    mz = mz * norm;

    # Reference direction of Earth's magnetic field
    q1mx2x = 2.0 * quat.q1 * mx
    q1my2x = 2.0 * quat.q1 * my
    q1mz2x = 2.0 * quat.q1 * mz
    q2mx2x = 2.0 * quat.q2 * mx
    hx = mx * q1q1 - q1my2x * quat.q4 + q1mz2x * quat.q3 + mx * q2q2 + q2x2 * my * quat.q3 + q2x2 * mz * quat.q4 - mx * q3q3 - mx * q4q4
    hy = q1mx2x * quat.q4 + my * q1q1 - q1mz2x * quat.q2 + q2mx2x * quat.q3 - my * q2q2 + my * q3q3 + q3x2 * mz * quat.q4 - my * q4q4
    v2bx = :math.sqrt(hx * hx + hy * hy)
    v2bz = -1.0 * q1mx2x * quat.q3 + q1my2x * quat.q2 + mz * q1q1 + q2mx2x * quat.q4 - mz * q2q2 + q3x2 * my * quat.q4 - mz * q3q3 + mz * q4q4
    bx2x = 2.0 * v2bx
    bz2x = 2.0 * v2bz

    # Gradient decent algorithm corrective step
    s1 = -1.0 * q3x2 * (2.0 * q2q4 - q1q3x2 - ax) + q2x2 * (2.0 * q1q2 + q3q4x2 - ay) - v2bz * quat.q3 * (v2bx * (0.5 - q3q3 - q4q4) + v2bz * (q2q4 - q1q3) - mx) + (-v2bx * quat.q4 + v2bz * quat.q2) * (v2bx * (q2q3 - q1q4) + v2bz * (q1q2 + q3q4) - my) + v2bx * quat.q3 * (v2bx * (q1q3 + q2q4) + v2bz * (0.5 - q2q2 - q3q3) - mz)
    s2 = q4x2 * (2.0 * q2q4 - q1q3x2 - ax) + q1x2 * (2.0 * q1q2 + q3q4x2 - ay) - 4 * quat.q2 * (1 - 2.0 * q2q2 - 2.0 * q3q3 - az) + v2bz * quat.q4 * (v2bx * (0.5 - q3q3 - q4q4) + v2bz * (q2q4 - q1q3) - mx) + (v2bx * quat.q3 + v2bz *quat.q1) * (v2bx * (q2q3 - q1q4) + v2bz * (q1q2 + q3q4) - my) + (v2bx * quat.q4 - bz2x * quat.q2) * (v2bx * (q1q3 + q2q4) + v2bz * (0.5 - q2q2 - q3q3) - mz)
    s3 = -q1x2 * (2.0 * q2q4 - q1q3x2 - ax) + q4x2 * (2.0 * q1q2 + q3q4x2 - ay) - 4 * quat.q3 * (1 - 2.0 * q2q2 - 2.0 * q3q3 - az) + (-bx2x * quat.q3 - v2bz * quat.q1) * (v2bx * (0.5 - q3q3 - q4q4) + v2bz * (q2q4 - q1q3) - mx) + (v2bx * quat.q2 + v2bz * quat.q4) * (v2bx * (q2q3 - q1q4) + v2bz * (q1q2 + q3q4) - my) + (v2bx * quat.q1 - bz2x * quat.q3) * (v2bx * (q1q3 + q2q4) + v2bz * (0.5 - q2q2 - q3q3) - mz)
    s4 = q2x2 * (2.0 * q2q4 - q1q3x2 - ax) + q3x2 * (2.0 * q1q2 + q3q4x2 - ay) + (-bx2x * quat.q4 + v2bz * quat.q2) * (v2bx * (0.5 - q3q3 - q4q4) + v2bz * (q2q4 - q1q3) - mx) + (-v2bx * quat.q1 + v2bz * quat.q3) * (v2bx * (q2q3 - q1q4) + v2bz * (q1q2 + q3q4) - my) + v2bx * quat.q2 * (v2bx * (q1q3 + q2q4) + v2bz * (0.5 - q2q2 - q3q3) - mz)
    norm = 1.0 / :math.sqrt(s1 * s1 + s2 * s2 + s3 * s3 + s4 * s4)
    s1 = s1 * norm
    s2 = s2 * norm
    s3 = s3 * norm
    s4 = s4 * norm

    # Compute rate of change of quaternion
    qDot1 = 0.5 * (-1 * quat.q2 * gx - quat.q3 * gy - quat.q4 * gz) - beta * s1
    qDot2 = 0.5 * (quat.q1 * gx + quat.q3 * gz - quat.q4 * gy) - beta * s2
    qDot3 = 0.5 * (quat.q1 * gy - quat.q2 * gz + quat.q4 * gx) - beta * s3
    qDot4 = 0.5 * (quat.q1 * gz + quat.q2 * gy - quat.q3 * gx) - beta * s4

    # Integrate to yield quaternion
    norm = 1.0 / :math.sqrt(quat.q1 * quat.q1 + quat.q2 * quat.q2 + quat.q3 * quat.q3 + quat.q4 * quat.q4)
    %Bluemage.Quaternion{q1: ((quat.q1 + qDot1 * period) * norm), q2: (quat.q2 + qDot2 * period) * norm, q3: (quat.q3 + qDot3 * period) * norm, q4: (quat.q4 + qDot4 * period) * norm}
  end
end
