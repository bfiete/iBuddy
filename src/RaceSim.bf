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
			public int32 mClassNum;
			public double mLap;
			public float mBestLapTime;
			public float mMustRefuel;

			public float mSpeedFactor = 1.0f;

			public float mIncidentTimeLeft;
			public float mIncidentFactor;

			public float mCarHealth = 1.0f;
			public float mPitTimeLeft;
			public bool mWhiteFlagged;
			public bool mCheckerFlagged;
		}

		public double mTimeLeft;
		public List<Driver> mDrivers = new .() ~ DeleteContainerAndItems!(_);
		public float mAvgPitTime;
		public bool mPitStopRequired;

		public Random mRand ~ delete _;
		public bool mOnLastLap;
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
				newDriver.mClassNum = driver.mClassNum;
				newDriver.mLap = driver.mLap;
				newDriver.mBestLapTime = driver.mBestLapTime;
				newDriver.mMustRefuel = driver.mMustRefuel;
				rs.mDrivers.Add(newDriver);
			}
			rs.mAvgPitTime = mAvgPitTime;
			rs.mPitStopRequired = mPitStopRequired;
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
			float timeDelta = 1.0f;

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

				if (driver.mPitTimeLeft > 0)
				{
					driver.mPitTimeLeft -= timeDelta;
					continue;
				}

				float speedFactor = driver.mSpeedFactor;
				if (driver.mIncidentTimeLeft > 0)
				{
					driver.mIncidentTimeLeft -= timeDelta;
					speedFactor *= driver.mIncidentFactor;
				}

				int prevLap = (int)driver.mLap;

				double pctVel = (timeDelta / driver.mBestLapTime) * speedFactor;
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

					if (driver.mWhiteFlagged)
					{
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
						driver.mPitTimeLeft = mAvgPitTime;
					}
				}

				if (Rand() < 1/30.0f) // About every 30 seconds enter a new "speed factor"
					driver.mSpeedFactor = 0.98f + Rand()*0.04f; // (-2% to +2%)

				if (Rand() < 0.0001f)
				{
					driver.mIncidentFactor = Rand();
					driver.mIncidentTimeLeft = Rand()*4.0f + Rand()*4.0f + Rand()*4.0f;
				}
			}
		}
	}
}
