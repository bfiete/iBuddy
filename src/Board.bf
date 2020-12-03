#pragma warning disable 168
using Beefy.widgets;
using System;
using iRacing;
using System.Collections;
using System.Diagnostics;
using Beefy.gfx;
using System.IO;

namespace iBuddy
{
	class Board : Widget
	{
		public class Track
		{
			public class Node
			{
				public List<float> mVelHistory = new .() ~ delete _;
				public float mVelMedian;

				//public List<float> mTimePctHistory = new .() ~ delete _;
				//public float mTimePctMedian;
				public float mTimePct;

				public float mLastAccTrackPct;
				public double mAccPctVel;
				public int mAccCount;

				public float PctVel
				{
					get
					{
						if (mVelMedian != 0)
							return mVelMedian;
						if (mAccCount > 0)
							return (float)(mAccPctVel / mAccCount);
						return 0;
					}
				}
			}

			public String mName = new .() ~ delete _;
			public List<Node> mNodes = new .() ~ DeleteContainerAndItems!(_);

			public Node GetNode(float pct)
			{
				return mNodes[(int)(pct * mNodes.Count) % mNodes.Count];
			}

			public void Init()
			{
				mName.Set(gApp.mIRSdk.mTrackName);
				int nodeCount = 1536;
				for (int i < nodeCount)
				{
					mNodes.Add(new Node());
				}
			}

			public float GetTimePct(float trackPct)
			{
				/*var node = GetNode(trackPct);
				if (node.mTimePct != 0)
					return node.mTimePct;
				return trackPct;*/
				return trackPct;
			}
		}

		public class DriverInfo
		{
			public IRSdk.Driver mDriver;
			public int32 mLastInfoUpdateIdx;
			public float mTimeDiff;
			public float mCrudeTimeDiff;
		}

		public Track mTrack ~ delete _;
		public List<DriverInfo> mDriverInfo = new .() ~ DeleteContainerAndItems!(_);
		float mMouseDownX;
		float mMouseDownY;
		bool mWantStandingDisplay;
		RaceSim mRefRaceSim ~ delete _;
		List<int32> mSimEndLaps = new .() ~ delete _;
		int32 mSimEstEndLap;
		float mSimEstEndLapAvg;

		public bool mWasOnPitRoad;
		public float mRefuelAddAmt;
		public float mRefuelStartLevel;
		public float mRefuelSimAmt;
		public int32 mRefuelEstLaps;
		public bool mGotCheckered;

		public void GetActiveDrivers(List<IRSdk.Driver> driverList, out float refLapTime)
		{
			refLapTime = gApp.mIRSdk.mTrackLength * 20.0f;
			List<float> lapTimes = scope .();
			for (var driver in gApp.mIRSdk.mDrivers)
			{
				if (driver == null)
					continue;
				if (driver.mCalcLapDistPct < 0)
					continue;
				if (driver.mIsSpectator)
					continue;
				if (driver.mIsPaceCar)
					continue;
				driverList.Add(driver);
				if (driver.mLastLapTime > 0)
					lapTimes.Add(driver.mLastLapTime);
				if (driver.mBestLapTime > 0)
					lapTimes.Add(driver.mBestLapTime);
			}
			lapTimes.Sort();
			if (!lapTimes.IsEmpty)
				refLapTime = lapTimes[lapTimes.Count / 2];
			var focusDriver = gApp.mIRSdk.FocusedDriver;
			if ((focusDriver != null) && (focusDriver.mBestLapTime > 0))
				refLapTime = focusDriver.mBestLapTime;
		}

		public enum DriverDrawKind
		{
			Relative,
			RelativeCompact,
			Standings,
			Qualifying
		}

		public uint32 GetClassColor(int carClass)
		{
			var classInfo = gApp.mIRSdk.mClassMap[(.)carClass];
			return classInfo.mColor | 0xFF000000;
		}

		public float DrawDriver(Graphics g, IRSdk.Driver driver, float refLapTime, DriverDrawKind drawKind, int drawIdx)
		{
			var irSdk = gApp.mIRSdk;
			var focusDriver = gApp.mIRSdk.FocusedDriver;
			var driverInfo = mDriverInfo[driver.mIdx];
			var session = irSdk.mSessions[irSdk.mSessionNum];
			bool isQualifying = session.mKind == .Qualify;
			IRSdk.ClassInfo classInfo = null;
			irSdk.mClassMap.TryGetValue(driver.mCarClass, out classInfo);
			
			bool isRace = session.mKind == .Race;

			float estTime = driver.mEstTime;
			if (gApp.mIRSdk.mCamCarIdx != -1)
				estTime = estTime - gApp.mIRSdk.mDrivers[gApp.mIRSdk.mCamCarIdx].mEstTime;

			float driverLap = driver.mCalcLap + driver.mCalcLapDistPct;
			float focusDriverLap = focusDriver.mCalcLap + focusDriver.mCalcLapDistPct;
			int lapDelta = 0;

			float lapPctDelta = driver.mCalcLapDistPct - focusDriver.mCalcLapDistPct;
			if (lapPctDelta < 0)
				lapPctDelta += 1.0f;
			bool isAheadOfFocus = lapPctDelta < 0.5f;

			float fromPct;
			float toPct;
			if (isAheadOfFocus)
			{
				fromPct = focusDriver.mCalcLapDistPct;
				toPct = driver.mCalcLapDistPct;

				if (driverLap > focusDriverLap + 0.5f)
					lapDelta = 1;
				else if (driverLap < focusDriverLap)
					lapDelta = -1;
			}
			else
			{
				fromPct = driver.mCalcLapDistPct;
				toPct = focusDriver.mCalcLapDistPct;

				if (driverLap > focusDriverLap)
					lapDelta = 1;
				else if (driverLap < focusDriverLap - 0.5f)
					lapDelta = -1;
			}

			if (toPct < fromPct)
				toPct += 1.0f;

			if ((toPct - fromPct > 0.5f) && (drawKind != .Relative))
				return 0;

			int32 infoUpdateIdx = mUpdateCnt / 15;
			if (driverInfo.mLastInfoUpdateIdx != infoUpdateIdx)
			{
				driverInfo.mLastInfoUpdateIdx = infoUpdateIdx;

				float secDiff = -1;
				float crudeSecDiff = -1;
				if ((focusDriver.mCalcLapDistPct >= 0) && (driver.mCalcLapDistPct >= 0))
				{
					float crudePctVel = 0.0001f;
					if ((driver.mCalcLapDistPct > 0) && (focusDriver.mLapPctVel > 0))
					{
						float pctDiff = Math.Abs(focusDriver.mCalcLapDistPct - driver.mCalcLapDistPct);
						if (pctDiff > 0.5)
							pctDiff = 1.0f - pctDiff;

						if (refLapTime > 0)
						{
							float avgPctVel = 1.0f / refLapTime;
							crudePctVel = avgPctVel;
						}
						else
						{
							crudePctVel = (focusDriver.mLapPctVel + driver.mLapPctVel) / 2;
						}

						crudeSecDiff = pctDiff / crudePctVel;
					}

					if (mTrack != null)
					{
						secDiff = 0;
						float curPct = toPct;
						int divisions = 60;
						for (int div < divisions)
						{
							float fromDivPct = (float)div / divisions;
							float toDivPct = (float)(div + 1) / divisions;

							float checkFromPct = fromPct + (toPct - fromPct) * ((float)div / divisions);
							float checkToPct = fromPct + (toPct - fromPct) * ((float)(div + 1) / divisions);

							var checkNode = mTrack.GetNode(checkFromPct);
							var nodePctVel = checkNode.PctVel;

							if (nodePctVel <= 0)
								nodePctVel = crudePctVel;
							
							secDiff += (checkToPct - checkFromPct) / nodePctVel;
						}
					}

					if (secDiff == -1)
						secDiff = crudeSecDiff;

					driverInfo.mTimeDiff = secDiff;
					driverInfo.mCrudeTimeDiff = crudeSecDiff;
				}
			}

			if (driver == focusDriver)
			{
				using (g.PushColor(0xFF382410))
					g.FillRect(2, 0, mWidth - 2, 20);
			}
			else if ((drawIdx % 2 == 0) && (drawKind != .RelativeCompact))
			{
				using (g.PushColor(0xFF202020))
					g.FillRect(2, 0, mWidth - 2, 20);
			}

			uint32 driverColor = 0xFFFFFFFF;
			if ((isRace) && (drawKind != .Standings))
			{
				if (driver.mOnPitRoad)
					driverColor = 0xFF808090;
				if (lapDelta < 0)
					driverColor = 0xFF3291B0;
				else if (lapDelta > 0)
					driverColor = 0xFFFF5172;
			}
			if (driver == focusDriver)
				driverColor = 0xFFE1B710;

			uint32 classColor = GetClassColor(driver.mCarClass);

			uint32 timeDiffColor = (driver.mCarClass == focusDriver.mCarClass) ? 0xFFFFFFFF : 0xFF888888;
			if (driver == focusDriver)
				timeDiffColor = driverColor;

			// Show connection issue
			/*if (driver.mLapDistPct < 0)
				timeDiffColor = 0xFF0000FF;*/

			float lgFontYOfs = -6;
			float medFontYOfs = -3;

			if (drawKind == .RelativeCompact)
			{
				classColor = Color.Mult(classColor, 0xFFC0C0C0);
				driverColor = Color.Mult(driverColor, 0xFFC0C0C0);
				timeDiffColor = Color.Mult(timeDiffColor, 0xFFC0C0C0);

				g.SetFont(gApp.mMedFont);
				using (g.PushColor(classColor))
				{
					g.FillRect(0, 0, 4, 20);
				}

				float maxLen = 120.0f;

				var shortName = scope String(64);

				for (var section in driver.mName.Split(' '))
				{
					if (@section.MatchPos == driver.mName.Length)
					{
						shortName.Append(section);
						continue;
					}
					if (section.IsEmpty)
						continue;
					shortName.Append(section.Substring(0, 1));
					shortName.Append(' ');
				}

				/*int spaceCount = driver.mName.IndexOf(' ');
				if (spaceCount != -1)
				{
					shortName.Append(driver.mName, 0, 1);
					shortName.Append(driver.mName, spaceCount);
				}
				else
					shortName.Append(driver.mName);*/

				float longNameLen = g.mFont.GetWidth(driver.mName);
				float shortNameLen = g.mFont.GetWidth(shortName);

				var fm = FontMetrics();
				using (g.PushColor(driverColor))
					g.DrawString((longNameLen < maxLen) ? driver.mName : shortName, 6, 0, .Left, maxLen, .Ellipsis, &fm);
				float width = fm.mMaxWidth;
				
				if (driverInfo.mTimeDiff >= 0)
				{
					fm = .();
					using (g.PushColor(timeDiffColor))
						g.DrawString(scope $"{driverInfo.mTimeDiff:0.0}", width + 30, 0, .Centered, 0, .Overflow, &fm);
					width += Math.Max(fm.mMaxWidth, 38) + 10;
				}

				return width + 8;
			}
			
			float positionX = 18;
			float carNumX = 56;
			float nameX = 84;
			float pitX = 236;
			float licenseX = pitX + 100;
			float ratingX = licenseX + 42;
			float timeDiffX = ratingX + 118;
			float deltasX = timeDiffX + 30;

			g.SetFont(gApp.mLgMonoFont);
			if (driver.mCalcClassPosition > 0)
			{
				uint32 positionColor;
				int32 positionDelta = driver.mCalcClassPosition - driver.mClassPosition;
				if (driver.mClassPosition < 1)
					positionDelta = 0;
				if (driver.mCarClass == focusDriver.mCarClass)
				{
					if (positionDelta == 0)
						positionColor = 0xFFFFFFFF;
					else if (positionDelta < 0)
						positionColor = 0xFF80F080;
					else
						positionColor = 0xFFF08080;
				}
				else
				{
					if (positionDelta == 0)
						positionColor = 0xFFA8A8A8;
					else if (positionDelta < 0)
						positionColor = 0xFF90B890;
					else
						positionColor = 0xFFB8A0A0;
				}

				using (g.PushColor(positionColor))
				{
					/*if ((driver.mClassPosition != 0) && (driver.mClassPosition != driver.mCalcClassPosition))
						g.DrawString(scope $"{driver.mCalcClassPosition}|{driver.mClassPosition}", positionX, lgFontYOfs, .Centered);
					else*/
						g.DrawString(scope $"{driver.mCalcClassPosition}", positionX, lgFontYOfs, .Centered);
				}
			}

			//irSdk.mRadioTransmitCarIdx = focusDriver.mIdx;
			/*if (mWidgetWindow.IsKeyDown(.Shift))
			{
				focusDriver.mRadioShow = 1.0f;
			}*/

			using (g.PushColor(classColor))
			{
				g.SetFont(gApp.mSmMonoFont);
				using (g.PushColor(0xFF707070))
					g.FillRect(carNumX - 17, 0, 36, 20);

				if (driver.mRadioShow > 0)
				{
					float radioShow = driver.mRadioShow;
					if (radioShow < 1.0f)
						radioShow = Math.Min(driver.mRadioShow * 3.0f, 0.7f);
					using (g.PushColor(Color.Get(radioShow)))
					{
						for (int i = 0; i < 12; i++)
						{
							float height = (float)(
								Math.Sin(mUpdateCnt * -0.15 + i * 0.5) +
								Math.Sin(mUpdateCnt * 0.3 + i * 1.0) * 0.25 +
								1.8) * 2.0f * radioShow;
							g.FillRect(carNumX - 11 + i * 2, 10 - height, 1, height * 2 + 1);
						}
					}
				}
				else
					g.DrawString(scope $"#{driver.mCarNumber}", carNumX, -1, .Centered);
				g.SetFont(gApp.mLgMonoFont);
			}

			bool drawPit = false;
			float pitTime = 0;
			int pitLap = driver.mPitLap;
			bool onPitRoad = false;
			if ((session.mKind == .Race) && (driver.mCarClass == focusDriver.mCarClass))
			{
				pitTime = driver.mPitTime;
				if (driver.mPitEnterTick > 0)
				{
					float curPitTime = (float)(irSdk.mSessionTime - driver.mPitEnterTick);
					if (curPitTime >= 3)
					{
						onPitRoad = true;
						pitTime = curPitTime;
						pitLap = driver.mCurPitLap;
					}
				}

				if (pitTime > 0)
					drawPit = true;
			}

			using (g.PushColor(driverColor))
			{
				g.SetFont(gApp.mMedFont);
				float nameWidth = licenseX - nameX - 20;
				if (drawPit)
					nameWidth -= (licenseX - pitX) - 18;
				//g.DrawString(scope $"{driver.mName}llllllllllllllllllllllll", 72, 0, .Left, nameWidth, .Ellipsis);
				g.DrawString(driver.mName, nameX, 0, .Left, nameWidth, .Ellipsis);
			}

			g.SetFont(gApp.mLgMonoFont);
			if (drawPit)
			{
				g.SetFont(gApp.mSmMonoFont);

				String pitTimeStr = scope .(16);

				if (pitTime >= 10*60)
				{
					int sec = (int)Math.Round(pitTime);
					pitTimeStr.AppendF($"{sec / 60}m");
				}
				else if (pitTime > 60)
				{
					int sec = (int)Math.Round(pitTime);
					pitTimeStr.AppendF($"{sec / 60}:{sec % 60:00}");
				}
				else if (pitTime > 9.5)
					pitTimeStr.AppendF($"{(int)Math.Round(pitTime)}s");
				else
					pitTimeStr.AppendF($"{pitTime:0.0}s");

				using (g.PushColor(onPitRoad ? 0xFFA08040 : 0xFFA08040))
					g.FillRect(pitX, 0, 76, 20);
				using (g.PushColor(0xFF201000))
					g.FillRect(pitX + 38, 1, 37, 18);

				using (g.PushColor(0xFF402010))
					g.DrawString(scope $"L{Math.Max(pitLap, 1)}", pitX + 18, -1, .Centered);

				if (pitTime > 999)
					pitTime = 999;

				using (g.PushColor(onPitRoad ? 0xFFFFFFFF : 0xFFF4DA72))
					g.DrawString(scope $"{pitTimeStr}", pitX + 57, -1, .Centered);
				g.SetFont(gApp.mLgMonoFont);
			}

			/*if (driverInfo.mCrudeTimeDiff >= 0)
				g.DrawString(scope $"{driverInfo.mCrudeTimeDiff:0.0}", 300, 0);*/
			//g.DrawString(scope $"+{driver.mLapPctVel * 100.0:0.0}%", 350, 0);

			//g.DrawString(scope $"{(driver.mIRating / 100) / 10.0f:0.0}k \u{2303} {(int)Math.Round(driver.mIRatingChange)}", 300, 0, .Centered);

			// License
			{
				uint32 licColor = driver.mLicColor;
				if ((licColor == 0) && (driver.mLicString.StartsWith("R")))
					licColor = 0xE02020;
				g.SetFont(gApp.mTinyMonoFont);
				using (g.PushColor(0xFF000000 | licColor))
					g.FillRect(licenseX - 18, 2, 36, 16);

				uint32 licNameColor = 0xFF000000;
				if ((licColor == 0x0153DB) || (licColor == 0x000000))
					licNameColor = 0xFFFFFFFF;

				var licString = scope String(24);
				licString.Append(driver.mLicString);
				if (licString.Length > 4)
					licString.RemoveFromEnd(1);

				using (g.PushColor(licNameColor))
					g.DrawString(licString, licenseX, 2, .Centered);
			}

			// Rating
			{
				using (g.PushColor(0xFFFFFFFF))
					g.FillRect(ratingX - 19, 1, 80, 18);

				int32 rating = driver.mIRating;
				//rating += 7000;

				g.SetFont(gApp.mSmMonoFont);
				using (g.PushColor(0xFF000000))
					g.DrawString(scope $"{(rating / 100) / 10.0f:0.0}k", ratingX, -1, .Centered);
				
				using (g.PushColor((driver.mIRatingChange >= 0) ? 0xFF30A038 : 0xFFEC433B))
				{
					FontMetrics fm = .();

					//driver.mIRatingChange -= 80;

					int irChange = (int)Math.Round(Math.Abs(driver.mIRatingChange));
					if (irChange != 0)
					{
						g.DrawString(scope $"{irChange}", ratingX + 58, -1, .Right, 0, .Overflow, &fm);

						using (g.PushTranslate(0, 11))
						{
							using (g.PushScale(1, (driver.mIRatingChange >= 0) ? 1 : -1))
							{
								using (g.PushTranslate(ratingX + 54 - Math.Max(fm.mMaxWidth, 20) - 6, 2))
									g.Draw(gApp.mChevronImage, 0, -10);
							}
						}
					}
				}
			}

			g.SetFont(gApp.mLgMonoFont);
			if ((drawKind == .Standings) && (!isRace))
			{
				IRSdk.SessionDriverInfo sessionDriverInfo = null;
				session.mSessionDriverInfoMap.TryGetValue(driver.mIdx, out sessionDriverInfo);

				float bestLapTime = driver.mLatchedBestLapTime;
				if ((bestLapTime <= 0) && (sessionDriverInfo != null))
				{
					if (sessionDriverInfo.mBestLapTime >= 0)
						bestLapTime = sessionDriverInfo.mBestLapTime;
					else
						bestLapTime = sessionDriverInfo.mLastLapTime;
				}

				if ((session.mKind == .Qualify) && (sessionDriverInfo != null))
				{
					g.DrawString(scope $"L{sessionDriverInfo.mLapsComplete}", deltasX - 46, lgFontYOfs, .Centered);
				}

				if (bestLapTime > 0)
				{
					uint32 timeColor = driverColor;
					if ((driver.mClassPosition == 1) && (isQualifying))
						timeColor = 0xFFFF00FF;

					using (g.PushColor(timeColor))
						g.DrawString(scope $"{(int)(bestLapTime / 60)}:{(bestLapTime % 60.0f):00.000}", deltasX + 24, lgFontYOfs, .Centered);
				}

				return 0;
			}

			if (driverInfo.mTimeDiff >= 0)
			{
				float timeDiff = driverInfo.mTimeDiff;
				if (drawKind == .Standings)
				{
					/*if (driver.mName.Contains("Andrei"))
					{
						NOP!();
					}*/

					if (driver.mCalcLapDistPct < 0)
						timeDiff = -1;
					else if (isAheadOfFocus)
					{
						if (driverLap > focusDriverLap)
						{
							int lapsDiff = (int)(driverLap - focusDriverLap + 0.5f);
							timeDiff = Math.Abs((lapsDiff * focusDriver.mLatchedBestLapTime) + timeDiff);
						}
						else
						{
							int lapsDiff = (int)(focusDriverLap - driverLap + 0.5f);
							timeDiff = Math.Abs((lapsDiff * focusDriver.mLatchedBestLapTime) + timeDiff);
						}
					}
					else
					{
						if (driverLap > focusDriverLap)
						{
							int lapsDiff = (int)(driverLap - focusDriverLap + 0.5f);
							timeDiff = Math.Abs((lapsDiff * focusDriver.mLatchedBestLapTime) - timeDiff);
						}
						else
						{
							int lapsDiff = (int)(focusDriverLap - driverLap + 0.5f);
							timeDiff = Math.Abs((lapsDiff * focusDriver.mLatchedBestLapTime) - timeDiff);
						}
						//timeDiff = 0;
					}
				}

				using (g.PushColor(timeDiffColor))
				{
					String timeDiffStr = scope .(32);
					if (timeDiff == -1)
						timeDiffStr.Append("-");
					else if (timeDiff >= 99.9)
						timeDiffStr.AppendF($"{timeDiff:0}");
					else
						timeDiffStr.AppendF($"{timeDiff:0.0}");

					g.DrawString(timeDiffStr, timeDiffX, lgFontYOfs, .Right);
				}
			}

			//g.DrawString(scope $"{driver.mCalcLapDistPct * 100:0.0}% {driver.mLap} {driver.mCalcLap}", 500, 0);

			if ((driver == focusDriver) && (driver.mLatchLapTime > 0))
			{
				uint32 lapColor = driverColor;

				lapColor = Color.Lerp(0xFFFFFFFF, lapColor, Math.Clamp((float)(irSdk.mSessionTime - driver.mLatchLapSessionTime)*0.5f - 8.0f, 0, 1));

				g.SetFont(gApp.mMedMonoFont);
				using (g.PushColor(lapColor))
					g.DrawString(scope $"{(int)(driver.mLatchLapTime / 60)}:{(driver.mLatchLapTime % 60.0f):00.000}", deltasX + 44, medFontYOfs, .Centered);
				g.SetFont(gApp.mLgMonoFont);
			}
			else
			{
				for (var delta in driver.mDeltas)
				{
					String deltaStr = scope String(16);
					uint32 deltaColor;
					float fontYOfs = lgFontYOfs;

					if (delta case .Delta(float deltaTime))
					{
						if (driver == focusDriver)
							deltaColor = driverColor;
						else
						{
							if (driver.mCarClass == focusDriver.mCarClass)
							{
								g.SetFont(gApp.mLgMonoFont);
								if (deltaTime >= 0)
									deltaColor = 0xFF30A838;
								else
									deltaColor = 0xFFEC433B;
							}
							else
							{
								fontYOfs = medFontYOfs;
								g.SetFont(gApp.mMedMonoFont);
								if (deltaTime >= 0)
									deltaColor = 0xFF407040;
								else
									deltaColor = 0xFFA06060;
							}
						}

						float deltaVal = Math.Abs(deltaTime);
						if (deltaVal > 9.99)
							deltaStr.AppendF("{}", (int)Math.Round(deltaVal));
						else
							deltaStr.AppendF("{:0.0}", deltaVal);
					}
					else
					{
						deltaColor = 0xFFFFFFFF;
						deltaStr.Append("-");
					}

					using (g.PushColor(deltaColor))
						g.DrawString(deltaStr, deltasX + @delta.Index * 44, fontYOfs, .Centered);
				}

				if (driver.mQueuedDeltaLapTime != 0)
				{
					using (g.PushColor(0xFFA0A0A0))
						g.FillRect(deltasX + 108, 8, 2, 2);
				}
			}

			return 0;
		}

		void DrawMap(Graphics g, List<IRSdk.Driver> trackOrderList, int focusIdx)
		{
			var irSdk = gApp.mIRSdk;
			var focusDriver = irSdk.FocusedDriver;

			float GetMapX(float pct)
			{
				float drawPct = pct - focusDriver.mCalcLapDistPct + 0.5f;
				if (drawPct > 1)
					drawPct -= 1.0f;
				if (drawPct < 0)
					drawPct += 1.0f;
				drawPct = mTrack.GetTimePct(drawPct);

				return 4 + (drawPct) * (mWidth - (4 * 2));
			}

			using (g.PushColor(0xFFE0E0E0))
				g.FillRect(GetMapX(0) - 1, 2, 3, 24);

			//using (g.PushColor(0xFFE1B710))
			using (g.PushColor(0xFFFFFFFF))
				g.Draw(gApp.mMapPointerImage, GetMapX(focusDriver.mCalcLapDistPct) - gApp.mMapPointerImage.mWidth / 2 + 1, 24);

			/*float prevTimePct = 0;
			for (float mapPct = 0.0f; mapPct < 1.0f; mapPct += 0.002f)
			{
				var node = mTrack.GetNode(mapPct);
				float height = node.PctVel * 2000.0f + 1;
				g.FillRect(GetMapX(mapPct), 70 - height, 1, height);

				height = Math.Ceiling((node.mTimePct - prevTimePct) * 5000.0f);
				prevTimePct = node.mTimePct;
				using (g.PushColor(0xFFFF0000))
					g.FillRect(GetMapX(mapPct), 90 - height, 1, height);
			}*/

			//g.FillRect(GetMapX(focusDriver.mCalcLapDistPct), 2, 1, 24);

			// First draw cars not in our class and then draw our class
			for (int mapPass < 2)
			{
				//for (var driver in trackOrderList)
				for (int ofs < trackOrderList.Count)
				{
					var driver = trackOrderList[(focusIdx + ofs) % trackOrderList.Count];

					bool drawNow = (driver.mCarClass == focusDriver.mCarClass) == (mapPass == 1);
					if (!drawNow)
						continue;
					if (driver.mCalcLapDistPct < 0)
						continue;

					uint32 carColor = GetClassColor(driver.mCarClass);
					if (driver.mOnPitRoad)
						carColor = Color.Mult(carColor, 0xFF909090);
					using (g.PushColor(carColor))
						g.Draw(gApp.mMapCarImage, GetMapX(driver.mCalcLapDistPct) - gApp.mMapCarImage.mWidth / 2, 8);

					/*if (driver.mName == "Alberto R Lago")
					{
						using (g.PushColor(0xFFFF8000))
							g.FillRect(GetMapX(driver.mCalcLapDistPct) - 1, 0, 3, 40);
					}*/
				}
			}

			for (var classInfoKV in irSdk.mClassMap)
			{
				if (classInfoKV.key == focusDriver.mCarClass)
					continue;

				var classInfo = classInfoKV.value;
				if (classInfo.mBestLapTime <= 0)
					continue;
				if (focusDriver.mBestLapTime <= 0)
					continue;

				float lapDiff = classInfo.mBestLapTime - focusDriver.mBestLapTime;

				uint32 classColor = GetClassColor(classInfoKV.key);
				using (g.PushColor(classColor))
				{
					g.FillRect(GetMapX(focusDriver.mCalcLapDistPct + lapDiff / focusDriver.mBestLapTime), 2, 2, 24);
					/*using (g.PushColor(0xFFE0E0E0))
					{
						g.FillRect(GetMapX(focusDriver.mCalcLapDistPct + (lapDiff * 2) / focusDriver.mBestLapTime), 2 + 1, 2, 24 - 1*2);
					}*/
				}
			}
		}

		float GetLapsLeft()
		{
			var irSdk = gApp.mIRSdk;
			var focusedDriver = irSdk.FocusedDriver;
			var session = irSdk.mSessions[irSdk.mSessionNum];
			if (session.mLaps > 0)
			{
				return session.mLaps - (focusedDriver.mCalcLap + focusedDriver.mCalcLapDistPct) + 1;
			}
			else if (irSdk.mSessionTimeRemain > 0)
			{
				if (irSdk.mSessionState == .StateCheckered)
					return 1.0f - focusedDriver.mCalcLapDistPct;
				else
					return (float)(irSdk.mSessionTimeRemain / focusedDriver.mLatchedBestLapTime) + 1;
			}
			return 0;
		}

		float GetRefFuelUsage()
		{
			var irSdk = gApp.mIRSdk;
			List<float> orderedFuelUsage = scope .();
			for (int checkIdx = Math.Max(0, irSdk.mFuelLevelHistory.Count - 10); checkIdx < irSdk.mFuelLevelHistory.Count; checkIdx++)
			{
				var fuelUsage = irSdk.mFuelLevelHistory[checkIdx];
				if (fuelUsage > 0)
					orderedFuelUsage.Add(fuelUsage);
			}

			if (orderedFuelUsage.Count < 2)
				return 0;

			orderedFuelUsage.Sort(scope (lhs, rhs) => rhs <=> lhs);

			float refUsage = orderedFuelUsage[Math.Min((int)Math.Ceiling(orderedFuelUsage.Count) / 5, orderedFuelUsage.Count - 1)];
			return refUsage;
		}

		float LiterToDispUnit(float liters)
		{
			return liters * 0.264172f;
		}

		void DrawFuel(Graphics g)
		{
			var irSdk = gApp.mIRSdk;

			var focusedDriver = irSdk.FocusedDriver;
			var session = irSdk.mSessions[irSdk.mSessionNum];
			if (!focusedDriver.IsOnTrack)
				return;

			bool refueling = irSdk.mFuelFill > 0;

			float fuelLevel = irSdk.mFuelLevel;

			float maxTank = irSdk.mDriverCarFuelMax;
			
			float lapsLeft = GetLapsLeft();
			float refUsage = GetRefFuelUsage();
			float needFuel = refUsage * Math.Ceiling(lapsLeft);

			if (refUsage > 0)
			{
				float fuelLapsLeft = irSdk.mFuelLevel / refUsage;
				float prevFuelLapsAtLine = Math.Max(irSdk.mLastLapFuelLevel, irSdk.mFuelLevel) / refUsage;

				//Debug.WriteLine($"Fuel Level: {mFuelLevel*0.264172f:0.0} Fuel Usage: {refUsage*0.264172f:0.0} Refuel: {(needFuel - mFuelLevel)*0.264172f:0.0} NeedFuel: {needFuel*0.264172f:0.0} Tank: {maxTank*0.264172f:0.0}");

				uint32 fuelColor = 0xFFFFFFFF;

				if (fuelLapsLeft < lapsLeft)
				{
					// We can't make it to the end with the current fuel

					if (needFuel <= maxTank)
					{
						// Inside pit window
						fuelColor = 0xFF80FF80;
					}

					if (prevFuelLapsAtLine <= 2.3f)
					{
						// Pit this lap
						fuelColor = 0xFFFF0000;
					}
					else if (fuelLapsLeft <= 3.3f)
					{
						// Pit next lap
						fuelColor = 0xFFFFFF00;
					}
				}

				bool showLevel = false;
				if (irSdk.mSessionState == .StateCheckered)
					showLevel = true;
				bool isMultiline = refueling || showLevel;

				if (isMultiline)
				{
					g.SetFont(gApp.mMedMonoFont);
				}

				using (g.PushColor(fuelColor))
				{
					String fuelStr = scope $"Fuel Laps {fuelLapsLeft:0.0}";
					g.DrawString(fuelStr, 0, isMultiline ? -10 : 0, .Centered);
				}

				if ((refueling) && (irSdk.mDriverCarFuelKgPerLtr > 0))
				{
					float estRefuel = (lapsLeft - fuelLapsLeft) * refUsage;
					estRefuel = LiterToDispUnit(estRefuel);

					float refuelAmt = irSdk.mFuelAddKg;
					//float refuelAmt = irSdk.mFuelAddKg / irSdk.mDriverCarFuelKgPerLtr;
					refuelAmt = LiterToDispUnit(refuelAmt); // L to G

					float fuelDiff = refuelAmt - estRefuel;
					String deltaStr = ((fuelDiff > 0) ? "+" : "");
					g.DrawString(scope $"Refuel {refuelAmt:0.00} ({deltaStr}{fuelDiff:0.00})", 0, 10, .Centered);
				}
				else if (isMultiline)
				{
					g.DrawString(scope $"Fuel {(irSdk.mFuelLevel * 0.264172f):0.0} gal", 0, 10, .Centered);
				}

				//if (irSdk.mSessionState == .StateCheckered)
				//fuelStr.AppendF($" {(irSdk.mFuelLevel * 0.264172f):0.0} gal");
			}
		}

		public override void Draw(Graphics g)
		{
			base.Draw(g);

			using (g.PushColor(0xFF000010))
				g.FillRect(0, 0, mWidth, mHeight);

			var irSdk = gApp.mIRSdk;
			if (irSdk.mCamCarIdx == -1)
				return;

			var focusDriver = irSdk.FocusedDriver;
			if (focusDriver == null)
				return;

			List<IRSdk.Driver> trackOrderList = scope .();
			float refLapTime = 0;
			GetActiveDrivers(trackOrderList, out refLapTime);

			trackOrderList.Sort(scope (lhs, rhs) =>
				{
					return -(lhs.mCalcLapDistPct <=> rhs.mCalcLapDistPct);
				});

			int focusIdx = trackOrderList.IndexOf(focusDriver);
			int drawAround = 3;

			var session = irSdk.mSessions[irSdk.mSessionNum];
			bool isRace = session.mKind == .Race;

			for (int driverIdx < irSdk.mDrivers.Count)
			{
				if (driverIdx >= mDriverInfo.Count)
					mDriverInfo.Add(null);

				var driver = irSdk.mDrivers[driverIdx];
				if ((mDriverInfo[driverIdx] != null) && (mDriverInfo[driverIdx].mDriver != driver))
					DeleteAndNullify!(mDriverInfo[driverIdx]);
				if (mDriverInfo[driverIdx] == null)
				{
					var driverInfo = new DriverInfo();
					driverInfo.mDriver = driver;
					mDriverInfo[driverIdx] = driverInfo;
				}
			}

			g.SetFont(gApp.mLgMonoFont);

			bool isQualifying = session.mKind == .Qualify;
			bool drawRel = !isQualifying && (session.mKind != .Testing) && (!mWantStandingDisplay);
			bool drawMap = !isQualifying && (session.mKind != .Testing) && (focusIdx >= 0) && (mTrack != null);
			float topRowY = 40;
			float botRowY = mHeight - 32;
			float relDriverY = 188;

			uint32 flagColor = 0;
			bool isGuessedFlag = false;
			if (irSdk.mSessionFlags.HasFlag(.checkered))
				flagColor = 0xFF808080;
			else if (irSdk.mSessionFlags.HasFlag(.white))
				flagColor = 0xFFFFFFFF;
			else if (irSdk.mGuessWhiteFlagged)
			{
				isGuessedFlag = true;
				flagColor = 0xFFFFFFFF;
			}
			if (flagColor != 0)
			{
				using (g.PushColor(Color.Mult(flagColor, Color.Get(0.8f + Math.Sin(mUpdateCnt * 0.12f) * 0.2f))))
					g.FillRect(6, 24, 40, 20);
				if (isGuessedFlag)
				{
					using (g.PushColor(0xFF000000))
						g.DrawString("?", 6, 18, .Centered, 40);
				}
			}

			float trackTemp = (irSdk.mTrackTempCrew * 9/5) + 32;
			g.DrawString(scope $"{(int)Math.Round(trackTemp)}F", 6, topRowY);

			IRSdk.ClassInfo focusClassInfo = scope .();
			irSdk.mClassMap.TryGetValue(focusDriver.mCarClass, out focusClassInfo);

			if (focusClassInfo != null)
				g.DrawString(scope $"SoF {focusClassInfo.mSOF / 1000.0:0.0}K", mWidth / 2, topRowY, .Centered);

			using (g.PushTranslate(mWidth / 4, topRowY))
				DrawFuel(g);

			String maxIncidentCountStr = scope .(64);
			if (irSdk.mMaxIncidentCount > 0)
				maxIncidentCountStr.AppendF($"{irSdk.mMaxIncidentCount}");
			else
				maxIncidentCountStr.Append("-");

			g.DrawString(scope $"X  {irSdk.mIncidentCount}/{maxIncidentCountStr}", mWidth - 6, topRowY, .Right);

			if (drawMap)
				DrawMap(g, trackOrderList, focusIdx);

			if ((drawRel) && (focusDriver.IsOnTrack) && (!trackOrderList.IsEmpty) && (mTrack != null))
			{
				/*for (int i < drawAround * 2 + 1)
				{
					int driverIdx = (i + focusIdx - drawAround + trackOrderList.Count) % trackOrderList.Count;
					using (g.PushTranslate(4, i * 23 + 24))
					{
						var driver = trackOrderList[driverIdx];
						var driverInfo = mDriverInfo[driver.mIdx];
						trackOrderList[driverIdx] = null;
						if (driver == null)
							continue;

						DrawDriver(g, driver, refLapTime, .Relative);
					}
				}*/

				List<IRSdk.Driver> drawDriverList = scope .(10);
				for (int relDir = -1; relDir < 2; relDir += 2)
				{
					bool wantAhead = relDir < 0;

					int lineNum = 0;
					int drawIdx = focusIdx;

					void FlushDrivers()
					{
						if (drawDriverList.Count == 0)
							return;
						using (g.PushTranslate(0, relDriverY + 23 * lineNum * relDir))
						{
							if (drawDriverList.Count == 1)
								DrawDriver(g, drawDriverList[0], refLapTime, .Relative, lineNum);
							else
							{
								float drawX = 39;
								for (var driver in drawDriverList)
								{
									using (g.PushTranslate(drawX, 0))
									{
										float width = DrawDriver(g, driver, refLapTime, .RelativeCompact, lineNum);
										drawX += width;
										if (drawX > mWidth)
											break;
									}
								}
							}
						}
						lineNum++;
						drawDriverList.Clear();
					}

					if (relDir < 0)
					{
						drawDriverList.Add(focusDriver);
						FlushDrivers();
					}
					else
						lineNum++;

					bool prevWasTrivial = false;
					bool allowCompact = true;
					while (true)
					{
						drawIdx = (drawIdx + relDir + trackOrderList.Count) % trackOrderList.Count;
						var driver = trackOrderList[drawIdx];
						
						if (driver == focusDriver)
						{
							break;
						}
						else if (driver.IsAheadOf(focusDriver) != wantAhead)
						{
							FlushDrivers();
							break;
						}

						bool wantFlush = !allowCompact;
						if ((driver.mCarClass == focusDriver.mCarClass) || (lineNum == 1))
						{
							FlushDrivers();
							wantFlush = true;
						}

						if (lineNum >= 6)
							break;

						drawDriverList.Add(driver);

						if (wantFlush)
						{
							FlushDrivers();
						}
					}
				}
			}
			else if (focusClassInfo != null)
			{
				float drawY = 72;

				/*float drawY = 80;
				List<int32> classList = scope .();
				for (var classId in irSdk.mClassMap.Keys)
					classList.Add(classId);
				classList.Sort();

				for (var classId in classList)
				{
					var classData = irSdk.mClassMap[classId];
					for (var driver in classData.mOrderedDrivers)
					{
						using (g.PushTranslate(4, drawY))
							DrawDriver(g, driver, refLapTime, .Relative);
						drawY += 23;
					}

					drawY += 16;
				}*/

				int drawIdx = 0;
				for (int driverIdx < focusClassInfo.mOrderedDrivers.Count)
				{
					if ((driverIdx == 4) && (focusDriver.mCalcClassPosition > 10))
					{
						g.DrawString("...", 120, drawY - 22);
						drawY += 3;
						driverIdx = Math.Min(focusDriver.mCalcClassPosition - 5, focusClassInfo.mOrderedDrivers.Count - 7);
					}

					var driver = focusClassInfo.mOrderedDrivers[driverIdx];
					using (g.PushTranslate(0, drawY))
					{
						DrawDriver(g, driver, refLapTime, .Standings, drawIdx);
					}
					drawY += 23;
					if (drawY > mHeight - 50)
						break;
					drawIdx++;
				}

			}

			g.SetFont(gApp.mLgMonoFont);
			String timeLeftStr = scope .();
			
			double timeLeft = irSdk.mSessionTimeRemain;
			if (timeLeft < 0) // Show total session time
				timeLeft = session.mTime;

			if (session.mTime == 0)
				timeLeft = irSdk.mSessionTime;

			TimeSpan ts = TimeSpan((.)(timeLeft * TimeSpan.TicksPerSecond));
			
			if (timeLeft >= 60*60)
				timeLeftStr.AppendF($"{ts:hh\\:mm\\:ss}");
            else
				timeLeftStr.AppendF($"{ts:mm\\:ss}");

			if ((irSdk.mSessionState == .StateCheckered) || (irSdk.mSessionState == .StateCoolDown))
			{
				timeLeftStr.Set("-");
			}

			if (session.mTime > 0)
				timeLeftStr.AppendF($" / {(int)(session.mTime / 60)}m");

			String sessionKindStr = scope .(64);
			if (session.mKind == .Unknown)
				sessionKindStr.Append(session.mType);
			else
				session.mKind.ToString(sessionKindStr);

			g.DrawString(scope $"{sessionKindStr} {timeLeftStr}", 8, botRowY);

			if ((focusDriver.mCalcLap >= 1) || (session.mLaps > 0))
			{
				float showLap = Math.Max(focusDriver.mCalcLap, 0);

				if (session.mLaps > 0)
					g.DrawString(scope $"Lap {showLap}/{session.mLaps}", mWidth/2, botRowY, .Centered);
				else if (mSimEstEndLapAvg > 0)
					g.DrawString(scope $"Lap {showLap}/~{mSimEstEndLapAvg:0.0}", mWidth/2, botRowY, .Centered);
				else if ((irSdk.mEstLaps > 0) && (!isQualifying))
					g.DrawString(scope $"Lap {showLap}/~{irSdk.mEstLaps:0.00}", mWidth/2, botRowY, .Centered);
				else
					g.DrawString(scope $"Lap {showLap}", mWidth/2, botRowY, .Centered);
			}

			var time = DateTime.Now;
			var timeStr = scope String();
			timeStr.AppendF($"{DateTime.Now:HH:mm:}");
			float strWidth = g.mFont.GetWidth(timeStr);
			timeStr.AppendF($"{DateTime.Now:ss}");
			g.DrawString(timeStr, mWidth - strWidth - 30, botRowY);

			/*using (g.PushTranslate(0, 0))
				DrawDriver(g, );*/

			/*g.SetFont(gApp.mSmFont);
			g.DrawString("Brian Fiete 01:42:382", 60, 20);

			g.SetFont(gApp.mMedFont);
			g.DrawString("Brian Fiete 01:42:382", 60, 60);*/


		}

		void UpdateTrackPct(float refLapTime)
		{
			return;

			/*float avgPctVel = 1.0f / refLapTime;
			double totalTime = 0.0f;

			

			int totalStepCount = 0;
			for (int pass < 2)
			{
				int stepCount = 0;

				float pct = 0.0f;
				while (pct < 1.0f)
				{
					var node = mTrack.GetNode(pct);
					float pctVel = node.PctVel;
					if (pctVel <= 0.0001f)
						pctVel = avgPctVel;

					pct += pctVel * 0.001f;

					if (pass == 1)
						node.mTimePct = (float)(stepCount / (float)totalStepCount);

					stepCount++;

					/*{
						float pctVel = node.PctVel;
						if (pctVel <= 0.0001f)
							pctVel = avgPctVel;
						timeAcc += 1.0 / pctVel;
						//timeAcc += pctVel;

						if (pass == 1)
							node.mTimePct = (float)(timeAcc / totalTime);
					}*/
				}

				totalStepCount = stepCount;
			}*/
		}

		public void SetupRefSim(float refLapTime)
		{
			DeleteAndNullify!(mRefRaceSim);

			var irSdk = gApp.mIRSdk;
			var focusedDriver = irSdk.FocusedDriver;
			if ((focusedDriver == null) || (!focusedDriver.IsOnTrack))
				return;

			RaceSim sim = new .(0);
			sim.mPitStopRequired = true;

			float lapsLeft = GetLapsLeft();
			float refUsage = GetRefFuelUsage();

			float tankMaxLaps = irSdk.mDriverCarFuelMax / refUsage;

			List<float> pitTimes = scope .();
			pitTimes.Add(40);

			if (irSdk.mSessionFlags.HasFlag(.white))
			{
				sim.mOnLastLap = true;
			}

			int focusedSimDriverIdx = -1;
			sim.mTimeLeft = irSdk.mSessionTimeRemain;
			for (var classInfo in irSdk.mClassMap.Values)
			{
				for (var driver in classInfo.mOrderedDrivers)
				{
					if (driver.mCalcLap <= 0)
						continue;

					RaceSim.Driver simDriver = new .();

					simDriver.mName = new String(driver.mName);
					simDriver.mDriverIdx = driver.mIdx;
					simDriver.mBestLapTime = driver.mLatchedBestLapTime;
					if (simDriver.mBestLapTime <= 0)
						simDriver.mBestLapTime = refLapTime;
					simDriver.mLap = driver.mCalcLap + driver.mCalcLapDistPct;

					//int32 lapsSinceFueling = driver.mCalcLap;

					//TODO: Handle endurance races better.
					// Perhaps simulate a chance that a driver has to pit for a splash

					if ((driver.mPitEnterTick > 0) && (driver.mLapStartTicks.Count >= 3))
					{
						float curPitTime = (float)(irSdk.mSessionTime - driver.mPitEnterTick);
						if (curPitTime > 2.0f)
						{
							float lapTimeA = (float)(irSdk.mSessionTime - driver.mLapStartTicks[driver.mLapStartTicks.Count - 1]);
							float lapTimeB = (float)(irSdk.mSessionTime - driver.mLapStartTicks[driver.mLapStartTicks.Count - 2]);
							float lapTimeC = (float)(irSdk.mSessionTime - driver.mLapStartTicks[driver.mLapStartTicks.Count - 3]);

							//float curTwoLapTime = (lapTimeA < driver.mBestLapTime * 95f) ? lapTimeB : a;

							float curTwoLapTime = lapTimeB;
							if (lapTimeA < driver.mBestLapTime * 0.95f)
							{
								curTwoLapTime = lapTimeC;
							}

							float curExtraTime = curTwoLapTime - driver.mBestLapTime * 2;

							float timeInPit = (float)(irSdk.mSessionTime - driver.mPitEnterTick);

							// We add mAvgPitLapExtraTime later
							simDriver.mCurLapTimeOverride = simDriver.mBestLapTime - curExtraTime;

							// Always consider the pit lane to be at the VERY start of a lap
							simDriver.mLap = (int)simDriver.mLap + 0.001f;
						}
					}

					simDriver.mCheckerFlagged = driver.mCheckerFlagged;

					if (driver.mWhiteFlagged)
					{
						simDriver.mWhiteFlagged = true;
						sim.mOnLastLap = true;
					}

					if (simDriver.mCurLapTimeOverride > 0)
					{
						// Handled
					}
					else if ((driver.mPitLapExtraTime >= 20) && (driver.mPitLapExtraTime <= 120) && (driver.mPitLap > 3))
					{
						pitTimes.Add(driver.mPitLapExtraTime);

						float attemptedLapsWithoutRefueling = lapsLeft + (driver.mCalcLap - driver.mPitLap);
						if (attemptedLapsWithoutRefueling > tankMaxLaps * 1.1)
						{
							// Not enough fuel
							if (driver == focusedDriver)
								simDriver.mMustRefuel = 1.0f;
							else
							{
								simDriver.mMustRefuel = 0.85f;
							}
						}
						else
						{
							// Leave a chance we have to add a splash
							simDriver.mMustRefuel = 0.15f;
						}
					}
					else
					{
						simDriver.mMustRefuel = 1.0f;
					}

					if (driver == focusedDriver)
					{
						focusedSimDriverIdx = sim.mDrivers.Count;
					}

					sim.mDrivers.Add(simDriver);
				}
			}

			pitTimes.Sort();
			sim.mAvgPitLapExtraTime = pitTimes[(pitTimes.Count - 1) / 2];

			for (var simDriver in sim.mDrivers)
			{
				if (simDriver.mCurLapTimeOverride > 0)
					simDriver.mCurLapTimeOverride += sim.mAvgPitLapExtraTime;
			}

			mRefRaceSim = sim;
		}

		public void Simulate()
		{
			if (mRefRaceSim == null)
				return;

			var irSdk = gApp.mIRSdk;
			var focusedDriver = irSdk.FocusedDriver;
			if (focusedDriver == null)
				return;

			var sim = mRefRaceSim.Duplicate(mUpdateCnt);
			defer delete sim;


			RaceSim.Driver focusedSimDriver = null;
			for (var simDriver in sim.mDrivers)
				if (simDriver.mDriverIdx == focusedDriver.mIdx)
					focusedSimDriver = simDriver;

			if (focusedSimDriver == null)
				return;

			while (true)
			{
				sim.Simulate();
				if (focusedSimDriver.mCheckerFlagged)
				{
					mSimEndLaps.Add((int32)focusedSimDriver.mLap);
					if (mSimEndLaps.Count > 500)
						mSimEndLaps.RemoveAt(10);
					break;
				}
			}
		}

		public override void Update()
		{
			base.Update();

			var irSdk = gApp.mIRSdk;

			mWantStandingDisplay = mWidgetWindow.IsKeyDown(.Shift);

			if (gApp.mInputDevice != null)
			{
				String state = scope .();
				gApp.mInputDevice.GetState(state);
				if (state.Contains("Btn\t24"))
					mWantStandingDisplay = true;
			}

			if ((mTrack == null) || (mTrack.mName != irSdk.mTrackName))
			{
				delete mTrack;
				mTrack = new Track();
				mTrack.Init();
			}

			if (!irSdk.IsRunning)
				return;

			var focusedDriver = irSdk.FocusedDriver;

			if (focusedDriver != null)
			{
				float curPitTime = (float)(irSdk.mSessionTime - focusedDriver.mPitEnterTick);
				//bool onPitRoad = (focusedDriver.mOnPitRoad) && (curPitTime >= 2.0f);
				bool onPitRoad = focusedDriver.mOnPitRoad;
				if ((onPitRoad) && (!mWasOnPitRoad))
				{
					mRefuelStartLevel = irSdk.mFuelLevel;

					double curLap = focusedDriver.mCalcLap + focusedDriver.mCalcLapDistPct;

					float refUsage = GetRefFuelUsage();
					float wantFuel = (float)((mSimEstEndLap - curLap) * refUsage);
					float wantAddFuel = wantFuel - irSdk.mFuelLevel;
					mRefuelSimAmt = wantAddFuel;
					mRefuelEstLaps = mSimEstEndLap;
				}
				mWasOnPitRoad = onPitRoad;
			}
			
			if (irSdk.mFuelAddKg > 0)
				mRefuelAddAmt = irSdk.mFuelAddKg;

			List<IRSdk.Driver> trackOrderList = scope .();
			float refLapTime = 0;
			GetActiveDrivers(trackOrderList, out refLapTime);

			IRSdk.Session session = null;
			if ((irSdk.mSessionNum >= 0) && (irSdk.mSessionNum < irSdk.mSessions.Count))
				session = irSdk.mSessions[irSdk.mSessionNum];
			bool isRace = ((session != null) && (session.mType == "Race"));
			
			if (focusedDriver != null)
			{
				bool isPaceLap = isRace && (focusedDriver.mLap < 1);

				if ((focusedDriver.mCalcLapDistPct > 0) && (!isPaceLap))
				{
					var node = mTrack.GetNode(focusedDriver.mCalcLapDistPct);
					if ((node.mAccCount > 0) && (node.mLastAccTrackPct > focusedDriver.mCalcLapDistPct))
					{
						// This is from a previous recording
						float pctVel = (float)(node.mAccPctVel / node.mAccCount);
						node.mVelHistory.Add(pctVel);
						while (node.mVelHistory.Count > 10)
							node.mVelHistory.RemoveAt(0);

						List<float> orderedList = scope .(10);
						for (var val in node.mVelHistory)
							orderedList.Add(val);
						orderedList.Sort();

						node.mVelMedian = orderedList[orderedList.Count / 2];
						node.mAccCount = 0;
						node.mAccPctVel = 0;
					}

					float minLapPct = 0;
					if (refLapTime > 0)
					{
						float avgPctVel = 1.0f / refLapTime;
						// Discard speed if it's less than 8% the average speed
						minLapPct = avgPctVel * 0.08f;
					}

					if (focusedDriver.mLapPctVel > minLapPct)
					{
						node.mAccPctVel += focusedDriver.mLapPctVel;
						node.mAccCount++;
					}

					node.mLastAccTrackPct = focusedDriver.mCalcLapDistPct;
				}
			}

			if ((irSdk.mSessionState == .StateRacing) && (isRace) && (focusedDriver != null) && (focusedDriver.mCalcLap >= 3))
			{
				if ((mUpdateCnt % 60) == 0)
					SetupRefSim(refLapTime);

				if ((mUpdateCnt % 2) == 0)
					Simulate();
			}

			if (((mUpdateCnt % 60) == 0) && (mSimEndLaps.Count > 10))
			{
				List<int32> orderedSimEndLaps = scope .();
				double total = 0;
				for (var lap in mSimEndLaps)
				{
					orderedSimEndLaps.Add(lap);
					total += lap;
				}
				orderedSimEndLaps.Sort();
				mSimEstEndLap = orderedSimEndLaps[(orderedSimEndLaps.Count * 95) / 100];
				mSimEstEndLapAvg = (float)(total / mSimEndLaps.Count);
			}

			UpdateTrackPct(refLapTime);

			if (mWidgetWindow.IsKeyDown(.Control))
			{
				List<StringView> strList = scope .();
				for (var kv in gApp.mIRSdk.mVarMap)
				{
					strList.Add(kv.key);
				}
				strList.Sort();

				for (var sv in strList)
				{
					Debug.WriteLine(sv);
				}
			}

			if ((isRace) && (focusedDriver != null) && (irSdk.mSessionFlags.HasFlag(.checkered) && (!mGotCheckered) && (focusedDriver.mCalcLapDistPct < 0.25f)))
			{
				String logName = scope $"{gApp.mInstallDir}/fuel.log";
				FileStream fs = scope .();
				//fs.Open(logName, .Write, .None, 4096, .A)
				if (fs.Open(logName, .Append, .Write) case .Ok)
				{
					StreamWriter sw = scope .(fs, .UTF8, 4096);
					sw.WriteLine($"{DateTime.Now}\t{mTrack.mName}\t{focusedDriver.mCarClass}\t{LiterToDispUnit(GetRefFuelUsage()):0.00}\t{LiterToDispUnit(irSdk.mFuelLevelHistory.Back):0.00}\t{LiterToDispUnit(irSdk.mFuelLevel):0.00}\t{LiterToDispUnit(mRefuelStartLevel):0.00}\t{LiterToDispUnit(mRefuelAddAmt):0.00}\t{LiterToDispUnit(mRefuelSimAmt):0.00}\t{mRefuelEstLaps}\t{focusedDriver.mCalcLap}");
				}

				mGotCheckered = true;
			}

			/*if (isRace)
			{
				Simulate(refLapTime);
			}*/
		}

		public override void KeyDown(KeyCode keyCode, bool isRepeat)
		{
			base.KeyDown(keyCode, isRepeat);

			if (keyCode == .Tilde)
			{
				List<IRSdk.Driver> drivers = scope .();
				for (var driver in gApp.mIRSdk.mDrivers)
				{
					if (driver == null)
						continue;
					if (driver.mIsSpectator)
						continue;
					if (driver.mIsPaceCar)
						continue;
					if (driver.mCalcClassPosition == 0)
						continue;
					drivers.Add(driver);
				}

				drivers.Sort(scope (lhs, rhs) =>
					{
						if (lhs.mCarClass != rhs.mCarClass)
							return lhs.mCarClass <=> rhs.mCarClass;
						return lhs.mCalcClassPosition <=> rhs.mCalcClassPosition;
					});

				Debug.WriteLine();
				for (var driver in drivers)
				{
					String str = scope .();
					str.AppendF($"{driver.mCarClass} ");
					str.Append(driver.mName);
					while (str.Length < 36)
						str.Append(' ');
					str.AppendF($" {driver.mIRating} {(int)Math.Round(driver.mIRatingChange)}");
					Debug.WriteLine(str);
				}
			}

			/*if (keyCode == (.)'S')
			{
				List<IRSdk.Driver> trackOrderList = scope .();
				float refLapTime = 0;
				GetActiveDrivers(trackOrderList, out refLapTime);
				Simulate(refLapTime);
			}*/
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
