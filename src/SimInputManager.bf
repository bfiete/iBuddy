using System.Threading;
using System;
using System.IO;
using System.Diagnostics;
using System.Collections;
namespace iBuddy
{
	class SimInputManager
	{
		public struct InputEntry
		{
			public int32 mMin;
			public int32 mMax;
			public float mInput;
			public float? mOverride;
		}

		public bool mExiting;
		public Thread mThread ~ delete _;
		public InputEntry mAccel;
		public InputEntry mBrake;
		public InputEntry mClutch;

		public float mLastSpeed;
		public int32? mAccelTicks;
		public float mSpeedAcc;
		public int32 mSpeedCount;
		public int32 mBurstWaitTicks;
		public int32 mBurstTicks;
		public float mThrottle;
		public int32 mOverspeedTicks;
		public float mUnderspeedTicks;

		public this()
		{
			char8[512] path = .( 0, );
			int32 outLen = 512;
			Platform.BfpFileResult result = default;
			Platform.BfpDirectory_GetSysDirectory(.Documents, &path, &outLen, &result);

			String configPath = scope .(&path);
			configPath.Append("/iRacing/joyCalib.yaml");

			InputEntry* entryPtr = null;

			FileStream fs = scope .();
			fs.Open(configPath);
			StreamReader sr = scope .(fs, .UTF8, false, 4096);
			for (var res in sr.Lines)
			{
				var line = res.GetValueOrDefault();
				if (line == "     AxisName: 'X Axis'")
					entryPtr = &mAccel;
				if (line == "     AxisName: 'Y Axis'")
					entryPtr = &mBrake;
				if (line == "     AxisName: 'Z Axis'")
					entryPtr = &mClutch;

				int32 val = 0;
				int colonPos = line.IndexOf(':');
				if ((colonPos > 0) && (colonPos + 2 < line.Length))
					val = int32.Parse(line.Substring(colonPos + 2)).GetValueOrDefault();

				if (line.Contains("CalibMin"))
				{
					if (entryPtr != null)
						entryPtr.mMin = val;
				}

				if (line.Contains("CalibMax"))
				{
					if (entryPtr != null)
						entryPtr.mMax = val;
				}
			}

			mThread = new .(new => Proc);
			mThread.Start(false);
		}

		public ~this()
		{
			mExiting = true;
			mThread?.Join();
		}	

		public void Proc()
		{
			while (!mExiting)
			{
				Thread.Sleep(1);

				using (gApp.mMonitor.Enter())
				{
					if (gApp.mWheelbaseInputDevice == null)
						continue;

					int32 flags = 0;
					int accel = 0;
					int brake = 0;
					int clutch = 0;

					if (gApp.mWheelInputDevice != null)
					{
						String state = scope .();
						gApp.mWheelInputDevice.GetState(state);

						if (state.Contains("Btn\t4"))
							flags |= 1;
						if (state.Contains("Btn\t28"))
							flags |= 4;
						if (state.Contains("Btn\t29"))
							flags |= 2;
					}

					void HandleInputEntry(ref int val, ref InputEntry entry)
					{
						if (entry.mMax > entry.mMin)
							entry.mInput = (float)(val - entry.mMin) / (entry.mMax - entry.mMin);

						if (entry.mOverride != null)
							val = (.)Math.Round(entry.mMin + entry.mOverride.Value * (entry.mMax - entry.mMin));
					}

					if (gApp.mPedalsInputDevice != null)
					{
						String state = scope .();
						gApp.mPedalsInputDevice.GetState(state);

						for (var entry in state.Split('\n', .RemoveEmptyEntries))
						{
							var valEnum = entry.Split('\t');
							StringView name = valEnum.GetNext().Value;
							int val = int.Parse(valEnum.GetNext().Value).GetValueOrDefault();

							if (name == "Z")
								accel = val / 16;
							if (name == "Y")
								brake = val / 16;
							if (name == "X")
								clutch = val / 16;
						}

						if (gApp.mBoardWindow?.IsKeyDown((.)'1') == true)
							flags |= 1;
						if (gApp.mBoardWindow?.IsKeyDown((.)'2') == true)
							flags |= 2;
						if (gApp.mBoardWindow?.IsKeyDown((.)'3') == true)
							flags |= 4;
					}

					HandleInputEntry(ref accel, ref mAccel);
					HandleInputEntry(ref brake, ref mBrake);
					HandleInputEntry(ref clutch, ref mClutch);
					IBApp.VJoy_Set(accel, brake, clutch, flags);
				}
			}
		}

		

		public void Update()
		{
			float? accelOverride = null;
			float? brakeOverride = null;
			float? clutchOverride = null;

			float speed = gApp.mIRSdk.mSpeed * 2.23694f;
			float maxSpeed = gApp.mIRSdk.mPitSpeedLimit * 0.621371f;

			if ((speed < maxSpeed - 2) || (speed > maxSpeed + 2))
				mBurstWaitTicks = 0;

			if ((gApp.mBoard != null) && (gApp.mBoard.mPitstopState < .Slowed))
			{
				mOverspeedTicks = 0;
				mUnderspeedTicks = 0;
				mBurstTicks = 0;
				mBurstWaitTicks = 0;
				mThrottle = 0.15f;
			}

			if ((gApp.mBoard != null) && (gApp.mBoard.mPitstopState != .None))
			{
				if (speed < maxSpeed / 2)
					gApp.mBoard.mPitstopState = .Lane;

				if (gApp.mBoard.mPitstopState == .Approach)
				{
					if (mBrake.mInput > 0.1f)
						gApp.mBoard.mPitstopState = .Slowing;
				}
				else
				{
					float overage = 1.0f;
					mBurstWaitTicks++;

					if (mAccelTicks != null)
						mAccelTicks = mAccelTicks.Value + 1;

					if (speed < 0.1)
						mAccelTicks = null;

					if ((mLastSpeed < 0.1) && (speed > 0.1) && (mAccelTicks == null))
						mAccelTicks = 0;

					if (gApp.mBoard.mPitstopState == .Slowing)
					{
						if (speed <= maxSpeed)
							brakeOverride = 0;

						if (mBrake.mInput < 0.1f)
							gApp.mBoard.mPitstopState = .Slowed;
					}

					if (gApp.mBoard.mPitstopState == .Slowed)
					{
						if (mAccel.mInput > 0.5f)
							gApp.mBoard.mPitstopState = .Lane;
					}

					//float speedDelta = speed - mLastSpeed;
					//float futureSpeed = speed + speedDelta * 20;

					float speedTarget = maxSpeed + 0.85f;
					float reactSpeed = 0.2f;

					float wantAccel = 0;
					if (mBurstTicks > 0)
					{
						mBurstTicks--;
						wantAccel = mThrottle + 0.3f;
					}
					else if (speed < speedTarget - 2)
						wantAccel = 1.0f;
					else if (speed < speedTarget)
					{
						mOverspeedTicks = 0;
						mUnderspeedTicks++;

						if (mUnderspeedTicks > 10)
							mThrottle += 0.0002f;
						wantAccel = mThrottle;

						/*if (mBurstWaitTicks >= 20)
						{
							mBurstWaitTicks = 0;
							mBurstTicks = 15;
						}*/

						/*if (mUnderspeedTicks > 10)
							wantAccel = mThrottle + 0.2f;*/
					}
					else
					{
						if (mAccelTicks != null)
						{
							Debug.WriteLine($"Accel Ticks: {mAccelTicks}");
							mAccelTicks = null;
						}

						mUnderspeedTicks = 0;
						mOverspeedTicks++;
						mThrottle -= 0.0002f;

						if (speed > speedTarget + 0.1f)
						{
							wantAccel = 0;
						}
						else
						{
							wantAccel = mThrottle;

							if (mOverspeedTicks > 10)
								wantAccel = 0;
						}

						/*float highSpeed = Math.Max(speed, futureSpeed);

						if (speed > maxSpeed + overage + 2.0f)
						{
							wantAccel = 0;
							reactSpeed = 0.4f;
							mBurstTicks = 0;
						}
						else if (highSpeed > maxSpeed + overage * 2.0f)
						{
							wantAccel = 0;
							reactSpeed = 0.2f;
						}
						else if (highSpeed > maxSpeed + overage * 1.5f)
						{
							wantAccel = 0.0f;
							reactSpeed = 0.1f;
						}
						else if (highSpeed > maxSpeed + overage)
						{
							wantAccel = 0.0f;
							reactSpeed = 0.1f;
						}
						else
						{
							if (mAccel.mOverride.HasValue)
								wantAccel = mAccel.mOverride.Value;
							else
								wantAccel = 0.0f;
							reactSpeed = 0.1f;
						}*/
					}

					float curAccel = wantAccel;
					if (mAccel.mOverride.HasValue)
						curAccel = mAccel.mOverride.Value;
					accelOverride = curAccel + (wantAccel - curAccel) * reactSpeed;

					/*if (speed > 1)
					{
						if (gApp.mUpdateCnt % 30 == 0)
						{
							Debug.WriteLine($"Speed:{speed} MaxSpeed:{maxSpeed} WantAccel:{wantAccel} Accel:{accelOverride}");
						}
					}*/

					if (gApp.mBoard.mPitstopState == .Lane)
					{
						reactSpeed = 0.1f;
						accelOverride = Math.Min(accelOverride.Value, mAccel.mInput);
					}

					//float clutchSpeed = 20;
					float clutchSpeed = 20;
					if (speed < clutchSpeed)
					{
						float[] clutchTable = scope .(0.56f, 0.56f, 0.45f, 0.45f, 0.35f, 0.25f, 0.0f, 0.0f);

						int tableIdx = (int)((clutchTable.Count - 1) * (speed / clutchSpeed));

						float wantClutch = clutchTable[tableIdx];

						float curClutch = wantClutch;
						if (mClutch.mOverride.HasValue)
							curClutch = mClutch.mOverride.Value;
						clutchOverride = curClutch + (wantClutch - curClutch) * 0.2f;

						//clutchOverride = wantClutch;
					}

					mSpeedAcc += speed;
					mSpeedCount++;
					if (mSpeedCount >= 30)
					{
						float avgSpeed = mSpeedAcc / mSpeedCount;
						if (avgSpeed > 1.0f)
							Debug.WriteLine($"Avg Speed: {avgSpeed:0.00} MaxSpeed: {maxSpeed} Overage: {overage}");
						mSpeedAcc = 0;
						mSpeedCount = 0;
					}
				}
			}

			if (gApp.mBoard != null)
			{
				float dbgLoc = gApp.mBoard.mWidgetWindow.mMouseX / gApp.mBoard.mWidth;
				if (gApp.mBoard.mWidgetWindow.IsKeyDown((.)'A'))
					accelOverride = dbgLoc;
				if (gApp.mBoard.mWidgetWindow.IsKeyDown((.)'B'))
					brakeOverride = dbgLoc;
				if (gApp.mBoard.mWidgetWindow.IsKeyDown((.)'C'))
					clutchOverride = dbgLoc;
			}

			mBrake.mOverride = brakeOverride;
			mAccel.mOverride = accelOverride;
			mClutch.mOverride = clutchOverride;

			mLastSpeed = speed;
		}
	}
}
