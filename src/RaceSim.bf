using System.Collections;
using System;

namespace iBuddy
{
	//TODO: Make this work with races with multiple pitstops

	class RaceSim
	{
		public class Driver
		{
			public String mName ~ delete _;
			public int32 mDriverIdx;
			public int32 mClassNum;
			public double mLap;
			public float mBestLapTime;
			public float mMustRefuel;
			public bool mWhiteFlagged;
			public bool mCheckerFlagged;

			public float mSpeedFactor = 1.0f;

			public float mIncidentTimeLeft;
			public float mIncidentFactor;

			public float mCarHealth = 1.0f;
			public float mCurLapTimeOverride; // Pit stops are simulated by forcing a slower-than-normal lap
		}

		public double mTimeLeft;
		public List<Driver> mDrivers = new .() ~ DeleteContainerAndItems!(_);
		public float mAvgPitLapExtraTime;
		public bool mPitStopRequired;

		public Random mRand ~ delete _;
		public bool mOnLastLap;
		public bool mCheckerFlagged;
		public int32 mSimulateCount;

		public this(int32 seed)
		{
			mRand = new Random(seed);
		}

		public RaceSim Duplicate(int32 seed)
		{
			RaceSim rs = new .(seed);
			rs.mTimeLeft = mTimeLeft;
			for (var driver in mDrivers)
			{
				var newDriver = new Driver();
				if (driver.mName != null)
					newDriver.mName = new String(driver.mName);
				newDriver.mDriverIdx = driver.mDriverIdx;
				newDriver.mClassNum = driver.mClassNum;
				newDriver.mLap = driver.mLap;
				newDriver.mBestLapTime = driver.mBestLapTime;
				newDriver.mMustRefuel = driver.mMustRefuel;
				newDriver.mWhiteFlagged = driver.mWhiteFlagged;
				newDriver.mCheckerFlagged = driver.mCheckerFlagged;
				rs.mDrivers.Add(newDriver);
			}
			rs.mAvgPitLapExtraTime = mAvgPitLapExtraTime;
			rs.mPitStopRequired = mPitStopRequired;
			rs.mOnLastLap = mOnLastLap;
			return rs;
		}

		public float Rand()
		{
			return (float)mRand.NextDouble();
		}

		public Driver GetLeader()
		{
			Driver highestDriver = mDrivers[0];
			for (int i = 1; i < mDrivers.Count; i++)
			{
				var driver = mDrivers[i];
				if (driver.mLap > highestDriver.mLap)
					highestDriver = driver;
			}
			return highestDriver;
		}

		public void Simulate()
		{
			float timeDelta = 5.0f;

			if (mSimulateCount == 0)
			{
				for (var driver in mDrivers)
				{
					if (driver.mMustRefuel != 0)
						driver.mMustRefuel = (Rand() < driver.mMustRefuel) ? 1.0f : 0.0f;
				}
			}

			mSimulateCount++;
			mTimeLeft -= timeDelta;

			for (var driver in mDrivers)
			{
				if (driver.mCheckerFlagged)
					continue;

				float speedFactor = driver.mSpeedFactor;
				if (driver.mIncidentTimeLeft > 0)
				{
					driver.mIncidentTimeLeft -= timeDelta;
					speedFactor *= driver.mIncidentFactor;
				}

				int prevLap = (int)driver.mLap;

				float targetLapTime = driver.mBestLapTime;
				if (driver.mCurLapTimeOverride > 0)
					targetLapTime = driver.mCurLapTimeOverride;

				double pctVel = (timeDelta / targetLapTime) * speedFactor;
				driver.mLap += pctVel;

				if ((int)driver.mLap > prevLap)
				{
					/*driver.mFuelPct -= driver.mFuelPctPerLap;
					if (driver.mFuelPct < driver.mFuelPctPerLap)
					{
						// Putting
						driver.mFuelPct = 1.0f;
						driver.mPitTimeLeft = mAvgPitTime;
					}*/

					driver.mCurLapTimeOverride = 0;

					if ((driver.mWhiteFlagged) || (mCheckerFlagged))
					{
						mCheckerFlagged = true;
						driver.mCheckerFlagged = true;
						continue;
					}
					else if ((mTimeLeft <= driver.mBestLapTime) && (driver == GetLeader()))
					{
						mOnLastLap = true;
					}

					if (mOnLastLap)
						driver.mWhiteFlagged = true;

					if (driver.mMustRefuel > 0)
					{
						driver.mMustRefuel = 0;
						driver.mCurLapTimeOverride = driver.mBestLapTime + mAvgPitLapExtraTime;
					}
				}

				if (Rand() < timeDelta/30.0f) // About every 30 seconds enter a new "speed factor"
					driver.mSpeedFactor = 0.98f + Rand()*0.04f; // (-2% to +2%)

				if (Rand() < timeDelta/10000)
				{
					driver.mIncidentFactor = Rand();
					driver.mIncidentTimeLeft = Rand()*4.0f + Rand()*4.0f + Rand()*4.0f;
				}
			}
		}
	}
}
