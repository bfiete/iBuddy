using Beefy.widgets;
using Beefy.gfx;
using System.Collections;
using System;
using System.IO;
namespace iBuddy
{
	class LapInput
	{
		public struct State
		{
			public float mSpeed;
			public float mThrottle;
			public float mBrake;
			public int32 mGear;
		}

		public List<State> mHistory = new .() ~ delete _;
	}

	class LapInputWidget : Widget
	{
		public List<LapInput> mLapInputHistory = new List<LapInput>() ~ DeleteContainerAndItems!(_);
		public LapInput mLapInput ~ delete _;
		public LapInput mReferenceLap ~ delete _;

		float mMouseDownX;
		float mMouseDownY;
		double mShowPct;
		float mPrevLapDistPct;
		public int32 mPrevHistoryIdx = -1;
		public bool mRecording;
		public int32 mLapsSaved;

		public this(bool isRecording)
		{
			mRecording = isRecording;
			mLapInput = new LapInput();
		}

		public int32 TrackHistoryLen
		{
			get
			{
				return (int32)(gApp.mIRSdk.mTrackLength * 500.0) + 1;
			}
		}
		public int32 GetTrackHistoryIdx(double pct)
		{
			if (pct < 0)
				return -1;
			int32 trackLen = TrackHistoryLen;
			return (int32)Math.Min(pct * trackLen, trackLen - 1);
		}

		public void GetLapPath(String outLapPath)
		{
			var irSdk = gApp.mIRSdk;
			var focusedDriver = irSdk.FocusedDriver;
			String outLapName = scope $"{irSdk.mTrackName}{focusedDriver.mCarPath}.lap";
			outLapName.Replace(' ', '_');
			outLapPath.AppendF($"{gApp.mInstallDir}/laps/{outLapName}");
		}	

		bool SaveLap()
		{
			String lapPath = scope .();
			GetLapPath(lapPath);

			String lapDir = scope .();
			Path.GetDirectoryPath(lapPath, lapDir);
			Directory.CreateDirectory(lapDir).IgnoreError();

			FileStream fs = scope .();
			if (fs.Create(lapPath, .Write) case .Err)
				return false;

			// Version
			fs.Write((int32)0x1);
			fs.Write((int32)mLapInput.mHistory.Count);
			fs.TryWrite(.((uint8*)&mLapInput.mHistory[0], mLapInput.mHistory.Count * strideof(LapInput.State)));

			mLapsSaved++;

			return true;
		}

		bool LoadLap()
		{
			mReferenceLap = new LapInput();

			String lapPath = scope .();
			GetLapPath(lapPath);

			FileStream fs = scope .();
			if (fs.Open(lapPath, .Read) case .Err)
				return false;
			if (fs.Read<int32>().GetValueOrDefault() != 1)
				return false;

			int count = fs.Read<int32>().GetValueOrDefault();
			for (int i < count)
				mReferenceLap.mHistory.Add(.());
			if (fs.TryRead(.((uint8*)&mReferenceLap.mHistory[0], mReferenceLap.mHistory.Count * strideof(LapInput.State))) case .Err)
				return false;
			return true;
		}

		public override void Update()
		{
			base.Update();

			var irSdk = gApp.mIRSdk;
			if (!irSdk.IsRunning)
				return;
			var focusedDriver = irSdk.FocusedDriver;
			if (focusedDriver == null)
				return;
			if (focusedDriver.mCalcLapDistPct < 0)
				return;
			if (irSdk.mTrackName.IsEmpty)
				return;

			if ((!mRecording) && (mReferenceLap == null))
			{
				LoadLap();
			}

			if (mLapInput == null)
			{
				mLapInput = new LapInput();
			}

			LapInput.State state;
			state.mSpeed = irSdk.mSpeed;
			state.mThrottle = irSdk.mThrottle;
			state.mBrake = irSdk.mBrake;
			state.mGear = irSdk.mGear;

			int32 trackHistoryLen = TrackHistoryLen;
			int32 historyIdx = GetTrackHistoryIdx(focusedDriver.mCalcLapDistPct);
			if (mPrevHistoryIdx == -1)
				mPrevHistoryIdx = (int32)(historyIdx - 1);

			if ((historyIdx - mPrevHistoryIdx + trackHistoryLen) % trackHistoryLen > 5)
			{
				// Too big of a jump
				mPrevHistoryIdx = (int32)(historyIdx + trackHistoryLen - 1) % trackHistoryLen;
			}

			while (mLapInput.mHistory.Count < trackHistoryLen)
				mLapInput.mHistory.Add(default);

			if (state.mThrottle <= 0.05f)
			{
				int startHistoryIdx = (int32)(mPrevHistoryIdx + trackHistoryLen - 3) % trackHistoryLen;
				if ((mLapInput.mHistory[mPrevHistoryIdx].mThrottle >= 0.4f))
				{
					if (mLapInput.mHistory[startHistoryIdx].mThrottle <= 0.4f)
					{
						// Get rid of the blip
						int setHistoryIdx = startHistoryIdx;
						while (setHistoryIdx != historyIdx)
						{
							mLapInput.mHistory[setHistoryIdx].mThrottle = 0;
							setHistoryIdx = (setHistoryIdx + 1) % mLapInput.mHistory.Count;
						}
					}
				}
			}

			if (mPrevHistoryIdx != historyIdx)
			{
				for (int i = (mPrevHistoryIdx + 1) % mLapInput.mHistory.Count; true; i = (i + 1) % trackHistoryLen)
				{
					mLapInput.mHistory[i] = state;

					if (!mRecording)
					{
						// Clear out ahead of recording cursor
						mLapInput.mHistory[(i + 200) % trackHistoryLen] = .();

					}

					if (i == historyIdx)
						break;
				}
			}
			mPrevHistoryIdx = historyIdx;

			double lastDelta = focusedDriver.mCalcLapDistPct - mPrevLapDistPct;
			double wantPct = focusedDriver.mCalcLapDistPct + lastDelta * 7;

			double delta = wantPct - mShowPct;
			if (delta < -0.75f)
				delta += 1.0f;
			if (mShowPct > 1.0f)
				mShowPct -= 1.0f;
			if (Math.Abs(delta) > 0.1f)
			{
				mShowPct = wantPct;
			}
			else if (delta > 0)
			{
				mShowPct += delta * 0.1f;
			}

			if ((mRecording) && (focusedDriver.mCalcLapDistPct < 0.25f) && (mPrevLapDistPct >= 0.75f))
			{
				int valueCount = 0;
				for (var entry in mLapInput.mHistory)
				{
					if (entry.mSpeed != 0)
						valueCount++;
				}
				bool isInitialized = valueCount > (int)(mLapInput.mHistory.Count * 0.90f);
				if (isInitialized)
				{
					// Finished a lap
					if (!SaveLap())
						gApp.Fail("Failed to save lap file");
				}
			}

			mPrevLapDistPct = focusedDriver.mCalcLapDistPct;
			
			//mShowPct = wantPct;

			/*int wantIdxCount = (int) (irSdk.mTrackLength * 500.0) + 1;
			mLapInput.mHistory.Add(state);
			if (mLapInput.mHistory.Count > wantIdxCount)
				mLapInput.mHistory.RemoveAt(0);*/
		}

		public override void Draw(Graphics g)
		{
			base.Draw(g);

			var irSDK = gApp.mIRSdk;
			float baselineY = 108;

			using (g.PushColor(0xFF00FF00))
			{
				float barHeight = irSDK.mThrottle * 100;
				g.FillRect(6, baselineY - barHeight, 4, barHeight);
			}

			using (g.PushColor(0xFFFF0000))
			{
				float barHeight = irSDK.mBrake * 100;
				g.FillRect(12, baselineY - barHeight, 4, barHeight);
			}

			g.SetFont(gApp.mMedMonoFont);

			/*using (g.PushColor(0xFFFF0000))
			{
				for (int i = 0; i < mLapInput.mHistory.Count; i++)
				{
					var entry = ref mLapInput.mHistory[i];
					float height = entry.mBrake * 100;
					g.FillRect(i + 100, mHeight - 20 - height, 1, height);
				}
			}*/

			var focusedDriver = irSDK.FocusedDriver;
			if (focusedDriver == null)
				return;

			if (mLapInput.mHistory.Count == 0)
				return;

			int32 historyIdx = GetTrackHistoryIdx(mShowPct);

			float prevThrottleY = 0;
			float prevBrakeY = 0;

			int prevRefGear = -1;
			int prevGear = -1;

			int historyLen = (int)mWidth - 28;
			int historyX = 22;

			float refGearDrawX = -1;
			g.SetFont(gApp.mTinyMonoFont);

			for (int i < historyLen)
			{
				int idx = (historyIdx - historyLen + 100 + mLapInput.mHistory.Count + i) % mLapInput.mHistory.Count;

				var entry = ref mLapInput.mHistory[idx];
				LapInput.State* referenceEntry = null;
				if ((!mRecording) && (idx < mReferenceLap.mHistory.Count))
					referenceEntry = &mReferenceLap.mHistory[idx];

				float x = i + historyX;

				void DrawLine(float val, ref float prevY)
				{
					float y = Math.Min(baselineY - Math.Round(val * 100), baselineY - 1);
					if (i == 0)
						prevY = y;

					if ((prevY == y) && (val < 0.01f))
						return;

					if (y < prevY)
						g.FillRect(x, y, 1, prevY - y + 1);
					else
						g.FillRect(x, prevY, 1, y - prevY + 1);
					prevY = y;
				}

				void DrawBar(float val)
				{
					float height = Math.Round(val * 100);
					g.FillRect(x, baselineY - height, 1, height);
				}

				if (referenceEntry != null)
				{
					using (g.PushColor(0xFF008000))
						DrawBar(referenceEntry.mThrottle);
					using (g.PushColor(0xFF800000))
						DrawBar(referenceEntry.mBrake);
				}
				
				using (g.PushColor(0xFF00FF00))
					DrawLine(entry.mThrottle, ref prevThrottleY);
				using (g.PushColor(0xFFFF0000))
					DrawLine(entry.mBrake, ref prevBrakeY);

				void DrawGear(int32 gear, bool isRef)
				{
					if (gear == 0)
						return;

					float y = baselineY + 1;
					//if ((!isRef) && (x - refGearDrawX < 8))
					if (!isRef)
						y += 12;

					g.FillRect(x, y, 1, 2);
					g.DrawString(scope $"{gear}", x, y - 1, .Centered);

					if (isRef)
						refGearDrawX = x;
				}

				if (referenceEntry != null)
				{
					float speedDelta = entry.mSpeed - referenceEntry.mSpeed;
					float centerX = 180;

					//speedDelta = 100;

					if ((entry.mSpeed == 0) || (referenceEntry.mSpeed == 0))
					{

					}
					else if (speedDelta > 0)
					{
						float height = Math.Round(Math.Min(speedDelta * 4, 56));
						using (g.PushColor(0xFF00FF00))
							g.FillRect(x, centerX - height, 1, height);
					}
					else
					{
						float height = Math.Round(Math.Min(-speedDelta * 4, 56));
						using (g.PushColor(0xFFFF0000))
							g.FillRect(x, centerX, 1, height);
					}

					if (prevRefGear != referenceEntry.mGear)
					{
						using (g.PushColor(0xFF808080))
							DrawGear(referenceEntry.mGear, true);
					}

					prevRefGear = referenceEntry.mGear;
				}

				if (entry.mGear != prevGear)
				{
					if (prevGear != -1)
						DrawGear(entry.mGear, false);
					prevGear = entry.mGear;
				}

				/*float height = entry.mThrottle * 100;
				using (g.PushColor(0xFF00FF00))
					g.FillRect(i + 100, mHeight - 20 - height, 1, height);

				height = entry.mBrake * 100;
				using (g.PushColor(0xFFFF0000))
					g.FillRect(i + 100, mHeight - 20 - height, 1, height);*/
			}

			using (g.PushColor(0xA0FFFFFF))
				g.FillRect(historyX + historyLen - 100, 0, 1, mHeight);

			g.DrawString(scope $"{(int)(irSDK.FocusedDriver.mCalcLapDistPct * 100)}", 12, 108, .Centered);

			if (mLapsSaved > 0)
			{
				var str = scope String();
				if (mLapsSaved > 1)
					str.AppendF($"Laps Saved: {mLapsSaved}");
				else
					str.AppendF("Lap Saved");
				g.DrawString(str, 120, 8);
			}
		}

		public override void MouseDown(float x, float y, int32 btn, int32 btnCount)
		{
			base.MouseDown(x, y, btn, btnCount);
			mMouseDownX = x;
			mMouseDownY = y;
		}

		public override void MouseMove(float x, float y)
		{
			base.MouseMove(x, y);

			if (mMouseDown)
			{
				float winX = x - mMouseDownX + mWidgetWindow.mClientX;
				float winY = y - mMouseDownY + mWidgetWindow.mClientY;
				mWidgetWindow.SetClientPosition(winX, winY);
			}
		}
	}
}
