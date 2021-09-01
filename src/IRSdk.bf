using System;
using System.Collections;
using iBuddy;
using System.Diagnostics;
using System.IO;
using Beefy.geom;

namespace iRacing
{
	class IRSdk
	{
		const String cDataValidEventName = "Local\\IRSDKDataValidEvent";
		const String cMemMapFilaname = "Local\\IRSDKMemMapFileName";

		const int cCarCount = 64;
		const int MAX_BUFS = 4;
		const int MAX_STRING = 32;
		// descriptions can be longer than max_string!
		const int MAX_DESC = 64; 

		// define markers for unlimited session lap and time
		const int UNLIMITED_LAPS = 32767;
		const float UNLIMITED_TIME = 604800.0f;

		// latest version of our telemetry headers
		const int VER = 2;

		enum StatusField : int32
		{
			stConnected   = 1
		}

		enum VarType : int32
		{
			// 1 byte
			char = 0,
			bool,

			// 4 bytes
			int,
			bitField,
			float,

			// 8 bytes
			double,

			//index, don't use
			ETCount
		}

		const int[(int)VarType.ETCount] VarTypeBytes =
		.(
			1,		// char
			1,		// bool

			4,		// int
			4,		// bitField
			4,		// float

			8		// double
		);

		// bit fields
		enum EngineWarnings : int32
		{
			waterTempWarning		= 0x01,
			fuelPressureWarning		= 0x02,
			oilPressureWarning		= 0x04,
			engineStalled			= 0x08,
			pitSpeedLimiter			= 0x10,
			revLimiterActive		= 0x20,
		}

		// global flags
		public enum SessionFlags : uint32
		{
			// global flags
			checkered				= 0x00000001,
			white					= 0x00000002,
			green					= 0x00000004,
			yellow					= 0x00000008,
			red						= 0x00000010,
			blue					= 0x00000020,
			debris					= 0x00000040,
			crossed					= 0x00000080,
			yellowWaving			= 0x00000100,
			oneLapToGreen			= 0x00000200,
			greenHeld				= 0x00000400,
			tenToGo					= 0x00000800,
			fiveToGo				= 0x00001000,
			randomWaving			= 0x00002000,
			caution					= 0x00004000,
			cautionWaving			= 0x00008000,

			// drivers black flags
			black				= 0x00010000,
			disqualify			= 0x00020000,
			servicible			= 0x00040000, // car is allowed service (not a flag)
			furled				= 0x00080000,
			repair				= 0x00100000,

			// start lights
			startHidden			= 0x10000000,
			startReady			= 0x20000000,
			startSet			= 0x40000000,
			startGo				= 0x80000000,
		}


		// status 
		public enum TrkLoc : int32
		{
			NotInWorld = -1,
			OffTrack,
			InPitStall,
			AproachingPits,
			OnTrack
		}

		public enum TrkSurf : int32
		{
			SurfaceNotInWorld = -1,
			UndefinedMaterial = 0,

			Asphalt1Material,
			Asphalt2Material,
			Asphalt3Material,
			Asphalt4Material,
			Concrete1Material,
			Concrete2Material,
			RacingDirt1Material,
			RacingDirt2Material,
			Paint1Material,
			Paint2Material,
			Rumble1Material,
			Rumble2Material,
			Rumble3Material,
			Rumble4Material,

			Grass1Material,
			Grass2Material,
			Grass3Material,
			Grass4Material,
			Dirt1Material,
			Dirt2Material,
			Dirt3Material,
			Dirt4Material,
			SandMaterial,
			Gravel1Material,
			Gravel2Material,
			GrasscreteMaterial,
			AstroturfMaterial,
		}

		public enum SessionState : int32
		{
			StateInvalid,
			StateGetInCar,
			StateWarmup,
			StateParadeLaps,
			StateRacing,
			StateCheckered,
			StateCoolDown
		}

		public enum CarLeftRight : int32
		{
			LROff,
			LRClear,			// no cars around us.
			LRCarLeft,		// there is a car to our left.
			LRCarRight,		// there is a car to our right.
			LRCarLeftRight,	// there are cars on each side.
			LR2CarsLeft,		// there are two cars to our left.
			LR2CarsRight		// there are two cars to our right.
		}

		public enum CameraState : int32
		{
			IsSessionScreen          = 0x0001, // the camera tool can only be activated if viewing the session screen (out of car)
			IsScenicActive           = 0x0002, // the scenic camera is active (no focus car)

			//these can be changed with a broadcast message
			CamToolActive            = 0x0004,
			UIHidden                 = 0x0008,
			UseAutoShotSelection     = 0x0010,
			UseTemporaryEdits        = 0x0020,
			UseKeyAcceleration       = 0x0040,
			UseKey10xAcceleration    = 0x0080,
			UseMouseAimMode          = 0x0100
		}

		public enum PitSvFlags : int32
		{
			LFTireChange		= 0x0001,
			RFTireChange		= 0x0002,
			LRTireChange		= 0x0004,
			RRTireChange		= 0x0008,

			FuelFill			= 0x0010,
			WindshieldTearoff	= 0x0020,
			FastRepair			= 0x0040
		}

		public enum PitSvStatus : int32
		{
			// status
			PitSvNone = 0,
			PitSvInProgress,
			PitSvComplete,

			// errors
			PitSvTooFarLeft = 100,
			PitSvTooFarRight,
			PitSvTooFarForward,
			PitSvTooFarBack,
			PitSvBadAngle,
			PitSvCantFixThat,
		}

		public enum PaceMode : int32
		{
			PaceModeSingleFileStart = 0,
			PaceModeDoubleFileStart,
			PaceModeSingleFileRestart,
			PaceModeDoubleFileRestart,
			PaceModeNotPacing,
		}

		public enum PaceFlags : int32
		{
			PaceFlagsEndOfLine = 0x01,
			PaceFlagsFreePass = 0x02,
			PaceFlagsWavedAround = 0x04,
		}

		public enum BroadcastMsg : int32
		{
			CamSwitchPos = 0,      // car position, group, camera
			CamSwitchNum,	      // driver #, group, camera
			CamSetState,           // irsdk_CameraState, unused, unused 
			ReplaySetPlaySpeed,    // speed, slowMotion, unused
			ReplaySetPlayPosition, // irsdk_RpyPosMode, Frame Number (high, low)
			ReplaySearch,          // irsdk_RpySrchMode, unused, unused
			ReplaySetState,        // irsdk_RpyStateMode, unused, unused
			ReloadTextures,        // irsdk_ReloadTexturesMode, carIdx, unused
			ChatComand,		      // irsdk_ChatCommandMode, subCommand, unused
			PitCommand,            // irsdk_PitCommandMode, parameter
			TelemCommand,		  // irsdk_TelemCommandMode, unused, unused
			FFBCommand,		      // irsdk_FFBCommandMode, value (float, high, low)
			ReplaySearchSessionTime, // sessionNum, sessionTimeMS (high, low)
			Last                   // unused placeholder
		}

		public enum ChatCommandMode : int32
		{
			Macro = 0,		// pass in a number from 1-15 representing the chat macro to launch
			BeginChat,		// Open up a new chat window
			Reply,			// Reply to last private chat
			Cancel			// Close chat window
		}

		public enum PitCommandMode : int32		// this only works when the driver is in the car
		{
			Clear = 0,			// Clear all pit checkboxes
			WS,				// Clean the winshield, using one tear off
			Fuel,				// Add fuel, optionally specify the amount to add in liters or pass '0' to use existing amount
			LF,				// Change the left front tire, optionally specifying the pressure in KPa or pass '0' to use existing pressure
			RF,				// right front
			LR,				// left rear
			RR,				// right rear
			ClearTires,		// Clear tire pit checkboxes
			FR,				// Request a fast repair
			ClearWS,			// Uncheck Clean the winshield checkbox
			ClearFR,			// Uncheck request a fast repair
			ClearFuel,			// Uncheck add fuel
		}

		//----
		//

		public struct VarHeader
		{
			public int32 type;			// VarType
			public int32 offset;			// offset fron start of buffer row
			public int32 count;			// number of entrys (array)
								// so length in bytes would be VarTypeBytes[type] * count
			public bool countAsTime;
			public uint8[3] pad;		// (16 byte align)

			public char8[MAX_STRING] name;
			public char8[MAX_DESC] desc;
			public char8[MAX_STRING] unit;	// something like "kg/m^2"

			void clear() mut
			{
				this = default;
			}
		}

		struct VarBuf
		{
			public int32 tickCount;		// used to detect changes in data
			public int32 bufOffset;		// offset from header
			public int32[2] pad;			// (16 byte align)
		}

		struct Header
		{
			public int32 ver;				// this api header version, see VER
			public int32 status;				// bitfield using StatusField
			public int32 tickRate;			// ticks per second (60 or 360 etc)

			// session information, updated periodicaly
			public int32 sessionInfoUpdate;	// Incremented when session info changes
			public int32 sessionInfoLen;		// Length in bytes of session info string
			public int32 sessionInfoOffset;	// Session info, encoded in YAML format

			// State data, output at tickRate

			public int32 numVars;			// length of arra pointed to by varHeaderOffset
			public int32 varHeaderOffset;	// offset to varHeader[numVars] array, Describes the variables received in varBuf

			public int32 numBuf;				// <= MAX_BUFS (3 for now)
			public int32 bufLen;				// length in bytes for one line
			public int32[2] pad1;			// (16 byte align)
			public VarBuf[MAX_BUFS] varBuf; // buffers of data being written to
		}

		// sub header used when writing telemetry to disk
		struct DiskSubHeader
		{
			public int64 sessionStartDate;
			public double sessionStartTime;
			public double sessionEndTime;
			public int32 sessionLapCount;
			public int32 sessionRecordCount;
		}

		public enum DeltaTime
		{
			case Awaiting;
			case Missed;
			case Delta(float time);
		}

		public class Driver
		{
			public String mName = new .() ~ delete _;
			public String mShortName = new .() ~ delete _;
			public int32 mIdx;
			public bool mIsPaceCar;
			public bool mIsSpectator;
			public int32 mUserId;
			public int32 mLastSessionId;
			public int32 mIRating;
			public float mIRatingChange;
			public String mLicString = new .() ~ delete _;
			public uint32 mLicColor;
			public int32 mCarNumber;
			public int32 mCarClass;
			public uint32 mCarClassColor;
			public int32 mCarClassRelSpeed;
			public String mCarPath = new .() ~ delete _;
			public float mCarClassMaxFuelPct;
			public float mRadioShow;

			public int32 mLap;
			public int32 mCalcLap = -1;
			public float mEstTime;
			public bool mOnPitRoad;
			public List<double> mLapStartTicks = new .() ~ delete _;
			public double mLapUnknownTime;
			public double mLapLastUnknownTime;
			public double mLastDistPctRecvTick;
			public float mLapDistPct;
			public float mCalcLapDistPct;
			public float mLapPctVel;
			public float mBestLapTime;
			public float mLastLapTime;
			public float mQueuedDeltaLapTime;
			public int32 mClassPosition;
			public int32 mCalcClassPosition;
			public int32 mPosition;
			public int32 mPaceLine;
			public int32 mPaceRow;
			public int32 mPaceSort;

			public int32 mLatchLap;
			public float mLatchLapTime;
			public double mLatchLapSessionTime;
			public float mLatchedBestLapTime;

			public int32 mPitLap = -1;
			public int32 mCurPitLap = -1;
			public float mPitEnterLapDistPct = -1;
			public double mLastPitEnterTick = -1;
			public double mPitEnterTick;
			public double mPitLeaveTick;
			public float mPitTime;
			public float mPitLapExtraTime;
			public int32 mPitFinishCount;
			public bool mWhiteFlagged;
			public bool mCheckerFlagged;

			public List<float> mRaceLapHistory = new .() ~ delete _;
			public List<DeltaTime> mDeltas = new .() ~ delete _;

			public bool IsOnTrack
			{
				get
				{
					return mLapDistPct >= 0;
				}
			}

			public bool IsAheadOf(Driver other)
			{
				float delta = mLapDistPct - other.mLapDistPct;
				if (delta < 0)
					delta += 1.0f;
				return delta < 0.5f;
			}
		}

		public enum SessionKind
		{
			Unknown,
			Race,
			Qualify,
			Testing,
			Practice
		}

		public class SessionDriverInfo
		{
			public int32 mDriverIdx;
			public float mLastLapTime;
			public float mBestLapTime;
			public int32 mIncidentCount;
			public int32 mLap;
			public int32 mLapsComplete;
		}

		public class Session
		{
			public SessionKind mKind;
			public String mType = new .() ~ delete _;
			public float mTime;
			public int32 mLaps;

			public Dictionary<int32, SessionDriverInfo> mSessionDriverInfoMap = new .() ~
				{
					for (var val in mSessionDriverInfoMap.Values)
						delete val;
					delete _;
				};
		}

		public class ClassInfo
		{
			public int32 mClassId;
			public float mSOF;
			public float mIRatingTotal;
			public float mSOFExpSum;
			public int32 mCarCount;
			public int32 mDNSCount;
			public int32 mHighestClassPosition;
			public int32 mClassIdx;
			public List<Driver> mOrderedDrivers = new .() ~ delete _;
			public float mBestLapTime;
			public uint32 mColor;
			public int32 mRelSpeed;
		}

		public class StreamRecordInfo
		{
			public FileStream mFile ~ delete _;
			public Stopwatch mTimer ~ delete _;
			public uint8* mDataPrev ~ delete _;
			public uint8* mDataCur ~ delete _;
			public int32 mImageSize;
		}

		StreamRecordInfo mStreamRecordInfo ~ delete _;
		Windows.Handle mFileMapping;
		void* mSharedMemory;
		int mSharedMemorySize;
		Windows.EventHandle mDataEvent;
		Header* mHeader;

		public Dictionary<StringView, VarHeader*> mVarMap = new .() ~ delete _;
		public Dictionary<int32, ClassInfo> mClassMap = new .() ~
			{
				for (var classInfo in mClassMap.Values)
					delete classInfo;
				delete _;
			};
		uint8[] mData ~ delete _;
		public int32 mDriverCarIdx = -1;
		public int32 mCamCarIdx = -1;
		public int32 mLastTickCount;
		public int32 mLastSessionUpdate = -1;
		public DateTime mLastValidTime;
		public int32 mGear;
		public float mBrake;
		public float mThrottle;
		public float mSpeed;
		public float mDriverCarFuelMax;
		public float mDriverCarFuelKgPerLtr;
		public String mDriverSetupName = new .() ~ delete _;
		public bool mDriverSetupIsModified;
		public float mFuelLevel;
		public float mLastLapFuelLevel;
		public float mFuelAddKg;
		public float mFuelFill;
		public bool mFinishedRace;
		public List<float> mFuelLevelHistory = new .() ~ delete _;

		public List<Session> mSessions = new .() ~ DeleteContainerAndItems!(_);
		public String mSessionType = new .() ~ delete _;
		public PaceMode mPaceMode;
		public SessionState mSessionState;
		public int32 mInvalidStateCount;
		public int32 mHighestInvalidStateCount;
		public SessionFlags mSessionFlags;
		public int32 mRadioTransmitCarIdx;
		public float mLapBestLapTime;
		public float mLapLastLapTime;
		public int32 mRaceLaps;
		public int32 mSessionLapsRemain;
		public float mAirDensity;
		public int32 mSessionNum = -1;
		public int32 mIncidentCount;
		public int32 mMaxIncidentCount;
		public double mSessionTime;
		public double mSessionTimeRemain;
		public float mAirTemp;
		public float mTrackTempCrew;
		public float mPitSpeedLimit;
		public float mTrackLength;
		public String mTrackName = new .() ~ delete _;
		public bool mGuessWhiteFlagged;
		public int32 mSessionHighestLap;

		public float mEstLaps;
		public int mPrevMostLaps;

		public List<Driver> mDrivers = new .() ~ DeleteContainerAndItems!(_);

		public bool IsInitialized
		{
			get
			{
				return !mDataEvent.IsInvalid;
			}
		}

		public bool IsRunning
		{
			get
			{
				if (mDataEvent.IsInvalid)
					return false;
				if (mHeader == null)
					return false;
				if((mHeader.status & (int)StatusField.stConnected) == 0)
					return false;
				return true;
			}
		}

		public bool IsRecordingStream
		{
			get
			{
				return mStreamRecordInfo != null;
			}
		}

		public Driver FocusedDriver
		{
			get
			{
				Driver driver = null;
				if (mCamCarIdx >= 0)
					driver = mDrivers[mCamCarIdx];
				if (mDriverCarIdx >= 0)
					driver = mDrivers[mDriverCarIdx];
				if (driver != null)
				{
					if ((driver.mIsPaceCar) || (driver.mIsSpectator))
						driver = null;
				}
				return driver;
			}
		}

		public bool IsMulticlass
		{
			get
			{
				return mClassMap.Count > 1;
			}
		}

		public this()
		{
			for (int carNum < cCarCount)
				mDrivers.Add(null);
		}

		enum SECTION_INFORMATION_CLASS
		{
		    SectionBasicInformation,
		    SectionImageInformation
		};

		[CRepr]
		struct SECTION_BASIC_INFORMATION
		{
		    public void* BaseAddress;
		    public uint32 AllocationAttributes;
		    public uint64 MaximumSize;
		}


		public Result<void> StartRecording(StringView filePath)
		{
			DeleteAndNullify!(mStreamRecordInfo);
			mStreamRecordInfo = new .();
			mStreamRecordInfo.mFile = new .();
			if (mStreamRecordInfo.mFile.Create(filePath, .Write) case .Err)
			{
				DeleteAndNullify!(mStreamRecordInfo);
				return .Err;
			}

			mStreamRecordInfo.mTimer = new Stopwatch();
			mStreamRecordInfo.mTimer.Start();
			mStreamRecordInfo.mFile.Write((int32)mSharedMemorySize);

			mStreamRecordInfo.mDataCur = new uint8[mSharedMemorySize]*;
			mStreamRecordInfo.mDataPrev = new uint8[mSharedMemorySize]*;
			
			return .Ok;
		}

		public void WriteFrame()
		{
			mStreamRecordInfo.mFile.Write((int32)mStreamRecordInfo.mTimer.ElapsedMilliseconds);

			Internal.MemCpy(mStreamRecordInfo.mDataCur, mSharedMemory, mSharedMemorySize);

			var data = mStreamRecordInfo.mDataCur;
			var prevData = mStreamRecordInfo.mDataPrev;

			List<uint8> buf = scope .(64*1024);

			int prevIdx = -1;
			for (int i = 0; i < mSharedMemorySize; i++)
			{
				if (data[i] != prevData[i])
				{
					int delta = i - prevIdx - 1;
					if (delta > 0xFFFF)
					{
						buf.Add(0xA3);
						buf.AddRange(.((.)&delta, 4));
					}
					else if (delta > 0xFF)
					{
						buf.Add(0xA2);
						buf.AddRange(.((.)&delta, 2));
					}
					else if (delta > 0)
					{
						buf.Add(0xA1);
						buf.Add((.)delta);
					}

					if ((data[i] >= 0xA0) && (data[i] <= 0xA4))
					{
						buf.Add(0xA0);
					}
					buf.Add(data[i]);

					prevIdx = i;
				}
			}
			buf.Add(0xA4);

			mStreamRecordInfo.mFile.TryWrite(buf);
			
			Internal.MemCpy(mStreamRecordInfo.mDataPrev, mStreamRecordInfo.mDataCur, mSharedMemorySize);
		}

		public void StopRecording()
		{
			if (mStreamRecordInfo != null)
			{
				Debug.WriteLine($"Recorded {mStreamRecordInfo.mFile.Length/1024}k with {mStreamRecordInfo.mImageSize/1024}k of image data");
			}

			DeleteAndNullify!(mStreamRecordInfo);
		}

		public void Close()
		{
			if (mFileMapping != default)
			{
				mFileMapping.Close();
				mFileMapping = default;
			}
			mSharedMemory = null;
			if (mDataEvent != default)
			{
				mDataEvent.Close();
				mDataEvent = default;
			}	
		}

		public Result<void> Init()
		{
			mFileMapping = Windows.OpenFileMappingA(Windows.SECTION_QUERY | Windows.SECTION_MAP_READ, false, cMemMapFilaname);
			if (mFileMapping.IsInvalid)
			{
				Close();
				return .Err;
			}

			function uint32 (Windows.Handle sectionHandle, SECTION_INFORMATION_CLASS informationClass, void* outInformationBuffer, int32 informationBufferSize, int* outResultLength) pfnNtQuerySection;
			pfnNtQuerySection = (.) Windows.GetProcAddress(Windows.GetModuleHandleA("ntdll.dll"), "NtQuerySection");

			SECTION_BASIC_INFORMATION sbi = default;
			int ucbRead = 0;
#unwarn
			var ntResult = pfnNtQuerySection(mFileMapping, .SectionBasicInformation, &sbi, sizeof(SECTION_BASIC_INFORMATION), &ucbRead);
			mSharedMemorySize = (int32)sbi.MaximumSize;

			mSharedMemory = Windows.MapViewOfFile(mFileMapping, Windows.FILE_MAP_READ, 0, 0, 0);

			mDataEvent = Windows.OpenEventA(Windows.SYNCHRONIZE, false, cDataValidEventName);
			if (mDataEvent.IsInvalid)
			{
				Close();
				return .Err;
			}

			return .Ok;
		}

		public void GetVarVal(StringView name, ref float val, int idx = 0)
		{
			if (mVarMap.TryGetValue(name, var value))
			{
				uint8* ptr = (uint8*)&mData[value.offset];
				if (value.type == (int)VarType.float)
					val = ((float*)ptr)[idx];
			}
		}

		public void GetVarVal(StringView name, ref double val, int idx = 0)
		{
			if (mVarMap.TryGetValue(name, var value))
			{
				uint8* ptr = (uint8*)&mData[value.offset];
				if (value.type == (int)VarType.double)
					val = ((double*)ptr)[idx];
			}
		}

		public void GetVarVal(StringView name, ref int32 val, int idx = 0)
		{
			if (mVarMap.TryGetValue(name, var value))
			{
				uint8* ptr = (uint8*)&mData[value.offset];
				if ((value.type == (int)VarType.int) || (value.type == (int)VarType.bitField))
					val = ((int32*)ptr)[idx];
			}
		}

		public void GetVarVal(StringView name, ref bool val, int idx = 0)
		{
			if (mVarMap.TryGetValue(name, var value))
			{
				uint8* ptr = (uint8*)&mData[value.offset];
				if (value.type == (int)VarType.bool)
					val = ((bool*)ptr)[idx];
			}
		}

		public void GetYamlVal(StringView line, ref float val)
		{
			int colonPos = line.IndexOf(':');
			if (colonPos + 2 >= line.Length)
				return;
			if (float.Parse(line.Substring(colonPos + 2)) case .Ok(var parsedVal))
				val = parsedVal;
		}

		public void GetYamlVal(StringView line, ref int32 val)
		{
			int colonPos = line.IndexOf(':');
			if (colonPos + 2 >= line.Length)
				return;
			if (int32.Parse(line.Substring(colonPos + 2)) case .Ok(var parsedVal))
				val = parsedVal;
		}

		public void GetYamlVal(StringView line, String val)
		{
			int colonPos = line.IndexOf(':');
			if (colonPos + 2 >= line.Length)
				return;
			val.Append(StringView(line, colonPos + 2));
		}

		public bool GetNewData()
		{
			// if sim is not active, then no new data
			if((mHeader.status & (int)StatusField.stConnected) == 0)
			{
				mLastTickCount = int32.MaxValue;
				return false;
			}

			int latest = 0;
			for(int i=1; i<mHeader.numBuf; i++)
				if(mHeader.varBuf[latest].tickCount < mHeader.varBuf[i].tickCount)
				   latest = i;	

			// if newer than last recieved, than report new data
			if(mLastTickCount < mHeader.varBuf[latest].tickCount)
			{
				// if asked to retrieve the data
				if (mData != null)
				{
					// try twice to get the data out
					for (int32 count = 0; count < 2; count++)
					{
						int32 curTickCount =  mHeader.varBuf[latest].tickCount;
						Internal.MemCpy(&mData[0], (uint8*)mSharedMemory + mHeader.varBuf[latest].bufOffset, mHeader.bufLen);
						if(curTickCount ==  mHeader.varBuf[latest].tickCount)
						{
							mLastTickCount = curTickCount;
							mLastValidTime = DateTime.Now;

							return true;
						}
					}
					// if here, the data changed out from under us.
					return false;
				}
				else
				{
					mLastTickCount =  mHeader.varBuf[latest].tickCount;
					mLastValidTime = DateTime.Now;
					return true;
				}
			}
			// if older than last recieved, than reset, we probably disconnected
			else if(mLastTickCount > mHeader.varBuf[latest].tickCount)
			{
				mLastTickCount =  mHeader.varBuf[latest].tickCount;
				return false;
			}
			// else the same, and nothing changed this tick
			return true;
		}

		// Function to calculate the Probability 
		static float Probability(float rating1,  
		                           float rating2) 
		{ 
		    return 1.0f * 1.0f / (1 + 1.0f *  
		            (float)(Math.Pow(10, 1.0f *  
		           (rating1 - rating2) / 400))); 
		} 
		  
		// Function to calculate Elo rating 
		// K is a constant. 
		// d determines whether Player A wins 
		// or Player B.  
		static void EloRating(ref float Ra, ref float Rb, int K, bool d) 
		{  
		  
		    // To calculate the Winning 
		    // Probability of Player B 
		    float Pb = Probability(Ra, Rb); 
		  
		    // To calculate the Winning 
		    // Probability of Player A 
		    float Pa = Probability(Rb, Ra); 
		  
		    // Case -1 When Player A wins 
		    // Updating the Elo Ratings 
		    if (d == true)
			{ 
		        Ra = Ra + K * (1 - Pa); 
		        Rb = Rb + K * (0 - Pb); 
		    } 
		  
		    // Case -2 When Player B wins 
		    // Updating the Elo Ratings 
		    else
			{ 
		        Ra = Ra + K * (0 - Pa); 
		        Rb = Rb + K * (1 - Pb); 
		    } 
		  
		    /*System.out.print("Updated Ratings:-\n"); 
		      
		    System.out.print("Ra = " + (Math.round( 
		               Ra * 1000000.0) / 1000000.0) 
		                 + " Rb = " + Math.round(Rb  
		                  * 1000000.0) / 1000000.0);*/ 
		} 

		/*//driver code 
		public static void main (String[] args) 
		{ 
		      
		    // Ra and Rb are current ELO ratings 
		    float Ra = 1200, Rb = 1000; 
		      
		    int K = 30; 
		    bool d = true; 
		      
		    EloRating(ref Ra, ref Rb, K, d); 
		}*/ 

		public void UpdateThread()
		{

		}

		public void Update()
		{
			if (!IsInitialized)
			{
				if (Init() case .Err)
					return;
			}

			if (mStreamRecordInfo != null)
			{
				WriteFrame();

				gApp.mCapture.mWantImage = true;
				using (gApp.mCapture.mMonitor.Enter())
				{
					if (!gApp.mCapture.mImage.IsEmpty)
					{
						mStreamRecordInfo.mImageSize += (int32)gApp.mCapture.mImage.Count;

						mStreamRecordInfo.mFile.Write((int32)-1);
						mStreamRecordInfo.mFile.Write((int32)gApp.mCapture.mImage.Count);
						mStreamRecordInfo.mFile.Write((Span<uint8>)gApp.mCapture.mImage);

						gApp.mCapture.mImage.Clear();
					}
				}
			}
			else
			{
				gApp.mCapture.mWantImage = false;
			}

			mVarMap.Clear();
			mHeader = (Header*)mSharedMemory;
			for (int varIdx < mHeader.numVars)
			{
				var varHeader = (VarHeader*)((uint8*)mSharedMemory + mHeader.varHeaderOffset) + varIdx;
				mVarMap.Add(StringView(&varHeader.name), varHeader);
			}

			if ((mData == null) || (mData.Count != mHeader.bufLen))
			{
				delete mData;
				mData = new uint8[mHeader.bufLen];
			}

			if (!GetNewData())
				return;

			//
			SessionState sessionState;
			{
				int32 sessionStateI = 0;
				GetVarVal("SessionState", ref sessionStateI);
				sessionState = (.)sessionStateI;
			}

			if (sessionState == .StateInvalid)
			{
				mInvalidStateCount++;

				mMaxIncidentCount = Math.Max(mMaxIncidentCount, mInvalidStateCount);

				if (mInvalidStateCount < 120)
				{
					// Retain non-invalid state for a while
					return;
				}
			}
			else
			{
				mInvalidStateCount = 0;
			}

			int lineNum = 0;
			if (mHeader.sessionInfoUpdate != mLastSessionUpdate)
			{
				String sessionInfo = scope String()..Append(((char8*)mSharedMemory + mHeader.sessionInfoOffset));

				Driver driver = null;
				Session session = null;
				SessionDriverInfo sessionDriverInfo = null;

				for (var line in sessionInfo.Split('\n'))
				{
					lineNum++;

					if (line.StartsWith(" DriverCarFuelMaxLtr"))
					{
						GetYamlVal(line, ref mDriverCarFuelMax); 
					}
					else if (line.StartsWith(" DriverCarFuelKgPerLtr"))
					{
						GetYamlVal(line, ref mDriverCarFuelKgPerLtr);
					}
					else if (line.StartsWith(" DriverSetupName"))
					{
						mDriverSetupName.Clear();
						GetYamlVal(line, mDriverSetupName);
					}
					else if (line.StartsWith(" DriverSetupIsModified"))
					{
						int32 isModified = 0;
						GetYamlVal(line, ref isModified);
						mDriverSetupIsModified = isModified != 0;
					}
					else if (line.StartsWith("   SessionType:"))
					{
						mSessionType.Clear();
						GetYamlVal(line, mSessionType);
					}
					else if (line.StartsWith(" TrackName:"))
					{
						mTrackName.Clear();
						GetYamlVal(line, mTrackName);
					}
					else if (line.StartsWith(" TrackLength:"))
					{
						String trackLen = scope .();
						GetYamlVal(line, trackLen);
						if (trackLen.EndsWith(" km"))
						{
							trackLen.RemoveFromEnd(" km".Length);
							if (float.Parse(trackLen) case .Ok(out mTrackLength))
							{
							}
						}
					}
					else if (line.StartsWith(" TrackPitSpeedLimit:"))
					{
						String trackLen = scope .();
						GetYamlVal(line, trackLen);
						if (trackLen.EndsWith(" kph"))
						{
							trackLen.RemoveFromEnd(" kph".Length);
							if (float.Parse(trackLen) case .Ok(out mPitSpeedLimit))
							{
							}
						}
					}
					else if (line.StartsWith("  IncidentLimit:"))
					{
						GetYamlVal(line, ref mMaxIncidentCount);
					}
					else if (line.StartsWith(" - CarIdx:"))
					{
						int32 carNum = -1;
						GetYamlVal(line, ref carNum);
						if (carNum != -1)
						{
							driver = mDrivers[carNum];
							if (driver == null)
							{
								driver = new Driver();
								driver.mIdx = carNum;
								mDrivers[carNum] = driver;
							}
							driver.mLastSessionId = mHeader.sessionInfoUpdate;
						}
					}
					else if (line.StartsWith(" - SessionNum:"))
					{
						int32 sessionNum = 0;
						GetYamlVal(line, ref sessionNum);

						while (sessionNum >= mSessions.Count)
							mSessions.Add(null);
						if (mSessions[sessionNum] == null)
							mSessions[sessionNum] = new Session();
						session = mSessions[sessionNum];
						for (var kv in session.mSessionDriverInfoMap)
							delete kv.value;
						session.mSessionDriverInfoMap.Clear();
						sessionDriverInfo = null;
					}

					if (driver != null)
					{
						if (line.StartsWith("   UserName:"))
						{
							driver.mName.Clear();
							var name = scope String();
							GetYamlVal(line, name);
							for (var c in name.RawChars)
							{
								driver.mName.Append((char32)c);
							}
						}
						else if (line.StartsWith("   AbbrevName:"))
						{
							driver.mShortName.Clear();
							var name = scope String();
							GetYamlVal(line, name);
							for (var c in name.RawChars)
							{
								driver.mShortName.Append((char32)c);
							}
						}
						else if (line.StartsWith("   UserID:"))
						{
							int32 userId = -1;
							GetYamlVal(line, ref userId);
							if ((userId != driver.mUserId) && (driver.mUserId != 0))
							{
								// Replace with the new driver
								var oldDriver = driver;
								driver = new Driver();
								driver.mName.Set(oldDriver.mName);
								driver.mIdx = oldDriver.mIdx;
								mDrivers[driver.mIdx] = driver;
								delete oldDriver;
							}
							driver.mUserId = userId;
						}
						else if (line.StartsWith("   IRating:"))
						{
							GetYamlVal(line, ref driver.mIRating);
						}
						else if (line.StartsWith("   LicString:"))
						{
							driver.mLicString.Clear();
							GetYamlVal(line, driver.mLicString);
						}
						else if (line.StartsWith("   LicColor:"))
						{
							int32 color = 0;
							GetYamlVal(line, ref color);
							driver.mLicColor = (uint32)color;
						}
						else if (line.StartsWith("   IsSpectator:"))
						{
							int32 isSpectator = 0;
							GetYamlVal(line, ref isSpectator);
							driver.mIsSpectator = isSpectator != 0;
						}
						else if (line.StartsWith("   CarIsPaceCar:"))
						{
							int32 isPaceCar = 0;
							GetYamlVal(line, ref isPaceCar);
							driver.mIsPaceCar = isPaceCar != 0;
						}
						else if (line.StartsWith("   CarNumberRaw:"))
						{
							GetYamlVal(line, ref driver.mCarNumber);
						}
						else if (line.StartsWith("   CarClassID:"))
						{
							GetYamlVal(line, ref driver.mCarClass);
						}
						else if (line.StartsWith("   CarClassColor:"))
						{
							int32 color = 0;
							GetYamlVal(line, ref color);
							driver.mCarClassColor = (uint32)color;
						}
						else if (line.StartsWith("   CarClassRelspeed:"))
						{
							GetYamlVal(line, ref driver.mCarClassRelSpeed);
						}
						else if (line.StartsWith("   CarPath:"))
						{
							driver.mCarPath.Clear();
							GetYamlVal(line, driver.mCarPath);
						}
						else if (line.StartsWith("   CarClassMaxFuelPct:"))
						{
							String pct = scope .();
							GetYamlVal(line, pct);
							if (pct.EndsWith(" %"))
							{
								pct.RemoveFromEnd(" %".Length);
								if (float.Parse(pct) case .Ok(out driver.mCarClassMaxFuelPct))
								{
								}
							}
						}
					}

					if (session != null)
					{
						if (line.StartsWith("   SessionType:"))
						{
							session.mType.Clear();
							GetYamlVal(line, session.mType);
							if (session.mType.Contains("Race"))
								session.mKind = .Race;
							else if (session.mType.Contains("Qualify"))
								session.mKind = .Qualify;
							else if (session.mType.Contains("Practice"))
								session.mKind = .Practice;
							else if (session.mType.Contains("Testing"))
								session.mKind = .Testing;
						}
						else if (line.StartsWith("   SessionLaps:"))
						{
							GetYamlVal(line, ref session.mLaps);
						}
						else if (line.StartsWith("   SessionTime:"))
						{
							String timeStr = scope .();
							GetYamlVal(line, timeStr);
							if (timeStr.EndsWith(" sec"))
							{
								timeStr.RemoveFromEnd(" sec".Length);
								if (float.Parse(timeStr) case .Ok(out session.mTime))
								{
								}
							}
						}
						else if (line.StartsWith("     CarIdx:"))
						{
							int32 carIdx = 0;
							GetYamlVal(line, ref carIdx);
							if (session.mSessionDriverInfoMap.TryAdd(carIdx, var keyPtr, var valPtr))
							{
								sessionDriverInfo = new SessionDriverInfo();
								sessionDriverInfo.mDriverIdx = carIdx;
								*valPtr = sessionDriverInfo;
							}
						}
						else if (line.StartsWith("   ResultsFastestLap:"))
							sessionDriverInfo = null;
					}

					if (sessionDriverInfo != null)
					{
						if (line.StartsWith("     LastTime:"))
						{
							//Debug.Assert(sessionDriverInfo.mLastLapTime <= 0);
							GetYamlVal(line, ref sessionDriverInfo.mLastLapTime);
						}
						else if (line.StartsWith("     FastestTime:"))
						{
							//Debug.Assert(sessionDriverInfo.mBestLapTime <= 0);
							GetYamlVal(line, ref sessionDriverInfo.mBestLapTime);
						}
						else if (line.StartsWith("     Incidents:"))
						{
							GetYamlVal(line, ref sessionDriverInfo.mIncidentCount);
						}
						else if (line.StartsWith("     Lap:"))
						{
							GetYamlVal(line, ref sessionDriverInfo.mLap);
						}
						else if (line.StartsWith("     LapsComplete:"))
						{
							GetYamlVal(line, ref sessionDriverInfo.mLapsComplete);
						}
					}
				}

				for (var checkDriver in mDrivers)
				{
					if ((checkDriver != null) && (checkDriver.mLastSessionId != mHeader.sessionInfoUpdate))
					{
						delete checkDriver;
						@checkDriver.CurrentRef = null;
					}
				}

				mLastSessionUpdate = mHeader.sessionInfoUpdate;
			}

			double lastSessionTime = mSessionTime;
			int prevSessionNum = mSessionNum;

			GetVarVal("DriverCarIdx", ref mDriverCarIdx);
			GetVarVal("CamCarIdx", ref mCamCarIdx);
			GetVarVal("RaceLaps", ref mRaceLaps);
			GetVarVal("RadioTransmitCarIdx", ref mRadioTransmitCarIdx);
			mSessionState = (.)sessionState;
			int32 paceMode = 4;
			int32 sessionFlags = 0;
			GetVarVal("SessionFlags", ref sessionFlags);
			mSessionFlags = (.)sessionFlags;
			GetVarVal("PaceMode", ref paceMode);
			mPaceMode = (PaceMode)paceMode;
			GetVarVal("SessionNum", ref mSessionNum);
			GetVarVal("Gear", ref mGear);
			GetVarVal("Brake", ref mBrake);
			GetVarVal("Throttle", ref mThrottle);
			GetVarVal("Speed", ref mSpeed);
			GetVarVal("FuelLevel", ref mFuelLevel);
			GetVarVal("dpFuelAddKg", ref mFuelAddKg);
			GetVarVal("dpFuelFill", ref mFuelFill);

			GetVarVal("SessionLapsRemain", ref mSessionLapsRemain);
			GetVarVal("SessionTime", ref mSessionTime);
			GetVarVal("SessionTimeRemain", ref mSessionTimeRemain);
			GetVarVal("AirDensity", ref mAirDensity);
			GetVarVal("AirTemp", ref mAirTemp);
			GetVarVal("TrackTempCrew", ref mTrackTempCrew);
			GetVarVal("LapBestLapTime", ref mLapBestLapTime);
			GetVarVal("LapLastLapTime", ref mLapLastLapTime);
			GetVarVal("PlayerCarDriverIncidentCount", ref mIncidentCount);

			//
			//mCamCarIdx = 13;

			if (mLastLapFuelLevel <= 0)
				mLastLapFuelLevel = mFuelLevel;

			double sessionTimeDelta = mSessionTime - lastSessionTime;

			String timeLeftStr = scope .(32);
			TimeSpan ts = TimeSpan((.)(mSessionTimeRemain * TimeSpan.TicksPerSecond));
			timeLeftStr.AppendF($"{ts:mm\\:ss}");

			bool wantDebug = (gApp.mBoard != null) && (gApp.mBoard.mWidgetWindow.IsKeyDown(.Alt));
			if (wantDebug)
			{
				
			}

			Session session = null;
			if ((mSessionNum >= 0) && (mSessionNum < mSessions.Count))
				session = mSessions[mSessionNum];

			var focusedDriver = FocusedDriver;
			for (var driver in mDrivers)
			{
				if (driver == null)
					continue;

				double prevLapDist = driver.mLapDistPct;
				
				GetVarVal("CarIdxEstTime", ref driver.mEstTime, @driver.Index);
				GetVarVal("CarIdxLapDistPct", ref driver.mLapDistPct, @driver.Index);
				GetVarVal("CarIdxBestLapTime", ref driver.mBestLapTime, @driver.Index);
				GetVarVal("CarIdxLastLapTime", ref driver.mLastLapTime, @driver.Index);
				GetVarVal("CarIdxClassPosition", ref driver.mClassPosition, @driver.Index);
				GetVarVal("CarPosition", ref driver.mPosition, @driver.Index);
				GetVarVal("CarIdxPaceLine", ref driver.mPaceLine, @driver.Index);
				GetVarVal("CarIdxPaceRow", ref driver.mPaceRow, @driver.Index);
				driver.mCalcClassPosition = driver.mClassPosition;
				GetVarVal("CarIdxLap", ref driver.mLap, @driver.Index);
				GetVarVal("CarIdxOnPitRoad", ref driver.mOnPitRoad, @driver.Index);

				Vector3 vel = default;
				GetVarVal("VelocityX", ref vel.mX);
				GetVarVal("VelocityY", ref vel.mY);
				GetVarVal("VelocityZ", ref vel.mZ);

				if (driver.mLapDistPct >= 0)
				{
					driver.mCalcLapDistPct = driver.mLapDistPct;
					driver.mLastDistPctRecvTick = mSessionTime;
				}
				else if (mSessionTime - driver.mLastDistPctRecvTick > 8)
				{
					// Don't extrapolate out too far
					driver.mCalcLapDistPct = -1;
				}
				else if (driver.mCalcLapDistPct >= 0)
				{
					float refLapTime = driver.mLatchedBestLapTime;
					if (refLapTime <= 0)
					{
						driver.mCalcLapDistPct = -1;
					}
					else
					{
						float avgPctVel = 1.0f / refLapTime;
						driver.mCalcLapDistPct += (float)(avgPctVel * sessionTimeDelta);
					}
				}

				/*if (driver.mName.Contains("Cisco"))
				{
					NOP!();
				}*/	

				if (driver.mIdx == mRadioTransmitCarIdx)
					driver.mRadioShow = 1.0f;
				else
					driver.mRadioShow = Math.Max(driver.mRadioShow - 0.0075f, 0);

				if (driver.mBestLapTime >= 0)
					driver.mLatchedBestLapTime = driver.mBestLapTime;

				if (driver.mCalcLap == -1)
				{
					driver.mCalcLap = driver.mLap;
				}
				else if ((driver.mLap > driver.mCalcLap) && (driver.mLapDistPct < 0.5f))
				{
					if (driver.mLap > mSessionHighestLap)
					{
						if ((session.mKind == .Race) && (driver.mBestLapTime >= mSessionTimeRemain))
							mGuessWhiteFlagged = true;
						mSessionHighestLap = driver.mLap;
					}

					if ((mSessionFlags.HasFlag(.checkered)) || (driver.mWhiteFlagged))
					{
						driver.mCheckerFlagged = true;
					}

					if (mSessionFlags.HasFlag(.white))
					{
						driver.mWhiteFlagged = true;
						mGuessWhiteFlagged = true;
					}
					else
					{
						if ((driver == focusedDriver) && (mGuessWhiteFlagged))
						{
							// Oops- we were wrong!
							for (var driver in mDrivers)
							{
								if (driver == null)
									continue;
								driver.mWhiteFlagged = false;
								driver.mCheckerFlagged = false;
							}
							mGuessWhiteFlagged = false;
						}

						if (mGuessWhiteFlagged)
							driver.mWhiteFlagged = true;
					}

					driver.mCalcLap = driver.mLap;
					driver.mLapStartTicks.Add(mSessionTime);

					if (driver == focusedDriver)
					{
						float fuelDelta = mLastLapFuelLevel - mFuelLevel;
						mFuelLevelHistory.Add(fuelDelta);
						mLastLapFuelLevel = mFuelLevel;

						if (mSessionState == .StateCheckered)
							mFinishedRace = true;
					}
				}
				else if ((driver.mLap >= 0) && (driver.mLapDistPct > 0) && (driver.mLap < driver.mCalcLap))
				{
					driver.mCalcLap = driver.mLap;
				}

				if (driver.mLapDistPct < 0)
					driver.mLapUnknownTime += sessionTimeDelta;

				if ((driver.mOnPitRoad) && (mSessionTime > 0))
				{
					if (driver.mLapDistPct > 0.75f)
						driver.mCurPitLap = driver.mCalcLap + 1;
					else
						driver.mCurPitLap = driver.mLap;
					if (driver.mPitEnterTick == 0)
					{
						//float timeSinceLeave = (float)(mSessionTime - driver.mPitLeaveTime);
						//if ((timeSinceLeave < 30) && (driver.mPitLeaveTime > 0))
						if (driver.mLastPitEnterTick > 0)
						{
							//Debug.WriteLine($"{driver.mName} Entering Pits - extending. Time: {timeLeftStr}");

							driver.mPitTime = 0; // Reset
							driver.mPitEnterTick = driver.mLastPitEnterTick;
						}
						else
						{
							//Debug.WriteLine($"{driver.mName} Entering Pits - NEW. Time: {timeLeftStr}");

							driver.mPitTime = 0; // Reset
							driver.mPitEnterTick = mSessionTime;
						}
					}

					if (driver.mLapDistPct >= 0)
						driver.mPitEnterLapDistPct = driver.mLapDistPct;
				}
				else
				{
					if (driver.mPitEnterTick > 0)
					{
						float curPitTime = (float)(mSessionTime - driver.mPitEnterTick);

						// Filter out fake pittings
						if (curPitTime > 10.0f)
						{
							//Debug.WriteLine($"{driver.mName} Pit Time: {curPitTime} Lap: {driver.mCurPitLap} Time: {timeLeftStr}");

							driver.mPitLap = driver.mCurPitLap;
							driver.mPitTime = curPitTime;
							driver.mPitFinishCount++;
						}
						else
						{
							//Debug.WriteLine($"{driver.mName} Pit Time (ignored): {curPitTime} Lap: {driver.mCurPitLap} Time: {timeLeftStr}");
						}

						driver.mCurPitLap = -1;
						driver.mPitLeaveTick = mSessionTime;
						driver.mLastPitEnterTick = driver.mPitEnterTick;
						driver.mPitEnterTick = 0;
					}

					if ((driver.mLastPitEnterTick >= 0) && (driver.mPitEnterLapDistPct >= 0))
					{
						float distDelta = driver.mLapDistPct - driver.mPitEnterLapDistPct;
						if (distDelta < 0)
							distDelta += 1.0f;
						if (distDelta >= 0.5f)
						{
							// We've made it halfway around the track since getting the last pit signal
							driver.mLastPitEnterTick = -1;
							//Debug.WriteLine($"{driver.mName} Clearing pit enter time");
						}
					}
					/*if (driver.mLastPitEnterTime)
					{

					}*/
				}

				if ((driver.mLap > 0) && (driver.mLap != driver.mLatchLap) && (driver.mLastLapTime > 0) &&
					((driver.mLatchLapTime != driver.mLastLapTime) || (driver.mLapDistPct > 0.25f)))
				{
					if ((driver.mLap > 3) && (driver.mBestLapTime > 0) && ((driver.mLastLapTime - driver.mBestLapTime) > 25) &&
						(driver.mLapUnknownTime + driver.mLapLastUnknownTime > 40) && (driver.mPitTime == 0))
					{
						// Assume that we had a pitstop but it didn't show up in the data
						driver.mPitLap = driver.mLatchLap;
						driver.mPitTime = driver.mLastLapTime - driver.mBestLapTime;
					}

					if ((driver.mPitLap == driver.mLatchLap) && (driver.mPitTime > 0) && (driver.mLapStartTicks.Count >= 3))
					{
						//
						float lastTwoLapTime = (float)(driver.mLapStartTicks.Back - driver.mLapStartTicks[driver.mLapStartTicks.Count - 3]);
						float pitLapExtraTime = Math.Max(lastTwoLapTime - driver.mLatchedBestLapTime * 2, 0);

						// Take minimum 'extra lap time'. That will tend to drive our racesim to produce more conservative results
						if ((driver.mPitLapExtraTime == 0) || (pitLapExtraTime < driver.mPitLapExtraTime))
							driver.mPitLapExtraTime = pitLapExtraTime;
					}

					driver.mLapLastUnknownTime = driver.mLapUnknownTime;
					driver.mLapUnknownTime = 0;

					driver.mLatchLap = driver.mLap;
					driver.mLatchLapTime = driver.mLastLapTime;
					driver.mLatchLapSessionTime = mSessionTime;

					driver.mRaceLapHistory.Add(driver.mLastLapTime);
					driver.mQueuedDeltaLapTime = driver.mLastLapTime;
					if (driver == FocusedDriver)
					{
						for (var checkDriver in mDrivers)
						{
							if (checkDriver == null)
								continue;
							if ((!checkDriver.mDeltas.IsEmpty) && (checkDriver.mDeltas.Back case .Awaiting))
								checkDriver.mDeltas.Back = .Missed;
							checkDriver.mDeltas.Add(.Awaiting);
							if (checkDriver.mDeltas.Count > 3)
								checkDriver.mDeltas.RemoveAt(0);
						}

						if (mSessionState == .StateRacing)
						{
							double timeRemainingAtLine = mSessionTimeRemain + driver.mLapDistPct * driver.mLastLapTime;
							float bestLap = driver.mLastLapTime;
							if (driver.mBestLapTime > 0)
								bestLap = driver.mLastLapTime;
							float lapsLeft = (float)(timeRemainingAtLine / bestLap);

							mEstLaps = driver.mCalcLap + lapsLeft;
							mPrevMostLaps = driver.mCalcLap;
						}
					}

					/*if ((driver.mCalcLap > mPrevMostLaps) && (driver.mLap > 2))
					{
						double timeRemainingAtLine = mSessionTimeRemain + driver.mLapDistPct * driver.mLastLapTime;
						float bestLap = driver.mLastLapTime;
						if (driver.mBestLapTime > 0)
							bestLap = driver.mLastLapTime;
						float lapsLeft = (float)(timeRemainingAtLine / bestLap);

						mEstLaps = driver.mCalcLap + lapsLeft;
						mPrevMostLaps = driver.mCalcLap;
					}*/
				}

				/*if ((lap > 1) && (driver.mSoftLap == 0))
					driver.mSoftLap = lap;
				if (driver.mLapDistPct < 0.8f)
					driver.mSoftLap = lap;*/

				
				if ((driver.mDeltas.Count > 0) && (driver.mDeltas.Back case .Awaiting) && (focusedDriver != null))
				{
				   if ((driver.mQueuedDeltaLapTime > 0) && (focusedDriver.mLastLapTime > 0))
					{
						// Apply the delta time
						driver.mDeltas.Back = .Delta(driver.mQueuedDeltaLapTime - focusedDriver.mLatchLapTime);
						driver.mQueuedDeltaLapTime = 0;
					}
				}

				// Don't keep an "awaiting" slot for a driver in front of the focused driver
				if ((driver.mQueuedDeltaLapTime > 0) && (focusedDriver != null) && (focusedDriver.IsAheadOf(driver)))
				{
					if ((driver.mDeltas.Count > 0) && ((driver.mDeltas.Back case .Delta(var deltaTime))))
					{
						// Add the delta time to the previous delta
						driver.mDeltas.Back = .Delta(driver.mQueuedDeltaLapTime - focusedDriver.mLatchLapTime + deltaTime);
					}

					// If the focuedDriver is ahead of this driver then clear their latched time so we can have a fresh time to compare to
					driver.mQueuedDeltaLapTime = 0;
				}

				// Don't keep an "awaiting" slot for a driver in front of the focused driver
				if ((driver.mDeltas.Count > 0) && (driver.mDeltas.Back case .Awaiting) && (focusedDriver != null) && (driver.IsAheadOf(focusedDriver)))
				{
					driver.mDeltas.Back = .Missed;
				}

				double pctDelta = driver.mLapDistPct - prevLapDist;
				if (sessionTimeDelta > 0)
				{
					if ((pctDelta > 0) && (pctDelta < 1.0f))
					{
						float pctRate = (float)(pctDelta / sessionTimeDelta);
						driver.mLapPctVel = pctRate;
					}
				}
			}

			if (mSessionNum != prevSessionNum)
			{
				// Transition to new session
				mEstLaps = 0;
				mFuelLevelHistory.Clear();
				mLastLapFuelLevel = 0;
				mFinishedRace = false;
				mSessionHighestLap = 0;
				mGuessWhiteFlagged = false;
				for (var driver in mDrivers)
				{
					if (driver == null)
						continue;
					driver.mLapStartTicks.Clear();
					driver.mCalcLap = driver.mLap;
					driver.mCalcClassPosition = driver.mClassPosition;
					driver.mLatchedBestLapTime = 0;
					driver.mLatchLapTime = 0;
					driver.mLatchLap = 0;
					driver.mPitLap = -1;
					driver.mPitTime = 0;
					driver.mLastPitEnterTick = 0;
					driver.mPitEnterTick = 0;
					driver.mPitLeaveTick = 0;
					driver.mPitFinishCount = 0;
					driver.mWhiteFlagged = false;
					driver.mCheckerFlagged = false;
					driver.mDeltas.Clear();
				}
			}

			if (session != null)
			{
				if (session.mLaps > 0)
					mEstLaps = session.mLaps;
				else if ((session.mTime == 0) || (session.mKind != .Race))
					mEstLaps = 0;
			}

			for (var classData in mClassMap.Values)
				delete classData;
			mClassMap.Clear();

			int highestLap = 0;

			// Update class info
			for (var driver in mDrivers)
			{
				if (driver == null)
					continue;
				if (driver.mIsPaceCar)
					continue;
				if (driver.mIsSpectator)
					continue;

				highestLap = Math.Max(highestLap, driver.mCalcLap);

				driver.mIRatingChange = 0;
				if (mClassMap.TryAdd(driver.mCarClass, var keyPtr, var valuePtr))
					*valuePtr = new ClassInfo();
				var classInfo = *valuePtr;
				classInfo.mClassId = driver.mCarClass;
				classInfo.mCarCount++;
				classInfo.mIRatingTotal += driver.mIRating;
				classInfo.mColor = driver.mCarClassColor;
				classInfo.mRelSpeed = driver.mCarClassRelSpeed;
				if (driver.mBestLapTime > 0)
				{
					if (classInfo.mBestLapTime == 0)
						classInfo.mBestLapTime = driver.mBestLapTime;
					else
						classInfo.mBestLapTime = Math.Min(classInfo.mBestLapTime, driver.mBestLapTime);
				}
				classInfo.mHighestClassPosition = Math.Max(classInfo.mHighestClassPosition, driver.mClassPosition);

				if ((driver.mPaceSort == 0) && (driver.mPaceLine != -1))
					driver.mPaceSort = 1 + driver.mPaceRow * 2 + driver.mPaceLine;

				float br = 1600.0f / Math.Log(2);
				float sofExp = Math.Exp(-driver.mIRating / br);
				classInfo.mSOFExpSum += sofExp;
				classInfo.mOrderedDrivers.Add(driver);
			}

			for (var classData in mClassMap.Values)
			{
				classData.mOrderedDrivers.Sort(scope (lhs, rhs) =>
					{
						return lhs.mPaceSort <=> rhs.mPaceSort;
					});

				for (var driver in classData.mOrderedDrivers)
				{
					if ((driver.mCalcClassPosition == 0) && (driver.mPaceSort != 0))
						driver.mCalcClassPosition = ++classData.mHighestClassPosition;
				}

				classData.mOrderedDrivers.Sort(scope (lhs, rhs) => rhs.mIRating <=> lhs.mIRating);
				// Apply the DNS list
				for (var driver in classData.mOrderedDrivers)
				{
					if (driver.mCalcClassPosition == 0)
						driver.mCalcClassPosition = ++classData.mHighestClassPosition;
				}

				if (session.mKind == .Race)
				{
					float GetLapF(Driver driver)
					{
						if (driver.mCalcLapDistPct < 0)
							return -1;
						return driver.mCalcLap + driver.mCalcLapDistPct;
					}

					classData.mOrderedDrivers.Sort(scope (lhs, rhs) =>
						{
							if ((lhs.mCalcLapDistPct < 0) || (rhs.mCalcLapDistPct < 0))
							{
								// If one of them is having network issues then use "official" positions
								return lhs.mCalcClassPosition <=> rhs.mCalcClassPosition;
							}

							if ((lhs.mCalcLap == 0) && (rhs.mCalcLap == 0))
							{
								// On the pace lap just leave the normal sorting
								return lhs.mCalcClassPosition <=> rhs.mCalcClassPosition;
							}

							return GetLapF(rhs) <=> GetLapF(lhs);
						});

					for (var driver in classData.mOrderedDrivers)
					{
						driver.mCalcClassPosition = (.)@driver.Index + 1;
					}
				}

				float br = 1600.0f / Math.Log(2);
				classData.mSOF = br * Math.Log(classData.mCarCount / classData.mSOFExpSum);
				classData.mOrderedDrivers.Sort(scope (lhs, rhs) => lhs.mCalcClassPosition <=> rhs.mCalcClassPosition);
			}

			List<ClassInfo> classList = scope .();
			for (var classInfo in mClassMap.Values)
				classList.Add(classInfo);
			classList.Sort(scope (lhs, rhs) => lhs.mRelSpeed <=> rhs.mRelSpeed);
			for (var classInfo in classList)
				classInfo.mClassIdx = (.)@classInfo.Index;

			for (var driver in mDrivers)
			{
				if (driver == null)
					continue;

				// Calculate irating change
				ClassInfo classData = null;
				mClassMap.TryGetValue(driver.mCarClass, out classData);

				if (classData != null)
				{
					int32 prevCalcLap = -1;
					float expectedScore = 0;
					for (var checkDriver in classData.mOrderedDrivers)
					{
						if (driver == checkDriver)
							continue;

						float br = 1600.0f / Math.Log(2);
						float val = (1.0f - Math.Exp(-driver.mIRating/br))*Math.Exp(-checkDriver.mIRating/br)/((1-Math.Exp(-checkDriver.mIRating/br))*
							Math.Exp(-driver.mIRating/br)+(1-Math.Exp(-driver.mIRating/br))*Math.Exp(-checkDriver.mIRating/br));
						expectedScore += val;
						prevCalcLap = checkDriver.mCalcLap;
					}

					float fudgeFactor = ((classData.mCarCount - (classData.mDNSCount/2.0f))/2.0f-driver.mCalcClassPosition)/100.0f;
					if (driver.mIRating > 1)
						driver.mIRatingChange = (classData.mCarCount - driver.mCalcClassPosition - expectedScore - fudgeFactor) * 200 / (classData.mCarCount-classData.mDNSCount);
					if (classData.mCarCount < 2)
						driver.mIRatingChange = 0;
				}
			}
		}
	}
}
